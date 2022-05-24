const { BigNumber } = require('ethers')
const snarkjs = require("snarkjs")
const fs = require("fs")

describe('ZkSafebox-test-2', function () {
    let accounts
    let provider
    let zkSafebox
    let usdt
    let busd

    before(async function () {
        accounts = await ethers.getSigners()
        provider = accounts[0].provider
    })

    it('deploy', async function () {
        const MockERC20 = await ethers.getContractFactory('MockERC20')
        usdt = await MockERC20.deploy('MockUSDT', 'USDT')
        await usdt.deployed()
        console.log('usdt deployed:', usdt.address)
		await usdt.mint(accounts[0].address, m(1000, 18))
        console.log('usdt mint to accounts[0]', d(await usdt.balanceOf(accounts[0].address), 18))
		await usdt.mint(accounts[1].address, m(1000, 18))
        console.log('usdt mint to accounts[1]', d(await usdt.balanceOf(accounts[1].address), 18))


        busd = await MockERC20.deploy('MockBUSD', 'BUSD')
        await busd.deployed()
        console.log('busd deployed:', busd.address)
		await busd.mint(accounts[0].address, m(1000, 18))
        console.log('busd mint to accounts[0]', d(await busd.balanceOf(accounts[0].address), 18))
		await busd.mint(accounts[1].address, m(1000, 18))
        console.log('busd mint to accounts[1]', d(await busd.balanceOf(accounts[1].address), 18))

        
        const ZkSafebox = await ethers.getContractFactory('ZkSafebox')
        zkSafebox = await ZkSafebox.deploy()
        await zkSafebox.deployed()
        console.log('zkSafebox deployed:', zkSafebox.address)
    })


    it('deposit', async function () {
        await usdt.connect(accounts[1]).approve(zkSafebox.address, m(100, 18))
        console.log('step 1 approve done')

        await zkSafebox.connect(accounts[1]).deposit(accounts[1].address, accounts[0].address, usdt.address, m(100, 18))
        console.log('step 2 deposit done')

        await print()
    })


    it('setBoxhash round1', async function () {
        let psw = 'abc123'

        let tokenAddr = '0x0' //hex or int
        let amount = '0' //hex or int
        let input = [stringToHex(psw), tokenAddr, amount]
        let data = await snarkjs.groth16.fullProve({in:input}, "./zk/main3_js/main3.wasm", "./zk/circuit_final.zkey")

        const vKey = JSON.parse(fs.readFileSync("./zk/verification_key.json"))
        const res = await snarkjs.groth16.verify(vKey, data.publicSignals, data.proof)

        if (res === true) {
            console.log("Verification OK")

            let pswHash = data.publicSignals[0]
            let allHash = data.publicSignals[3]
            let boxhash = ethers.utils.solidityKeccak256(['uint256', 'address'], [pswHash, accounts[0].address])

            let proof = [
                BigNumber.from(data.proof.pi_a[0]).toHexString(),
                BigNumber.from(data.proof.pi_a[1]).toHexString(),
                BigNumber.from(data.proof.pi_b[0][1]).toHexString(),
                BigNumber.from(data.proof.pi_b[0][0]).toHexString(),
                BigNumber.from(data.proof.pi_b[1][1]).toHexString(),
                BigNumber.from(data.proof.pi_b[1][0]).toHexString(),
                BigNumber.from(data.proof.pi_c[0]).toHexString(),
                BigNumber.from(data.proof.pi_c[1]).toHexString()
            ]

            // for new user, it's Zero
            await zkSafebox.setBoxhash([0,0,0,0,0,0,0,0], 0, 0, proof, pswHash, allHash, boxhash)
            console.log('setBoxhash done')

        } else {
            console.log("Invalid proof")
        }
    })


    it('withdraw round1', async function () {
        let psw = 'abc123'

        let tokenAddr = usdt.address //hex or int
        let amount = s(m(30, 18)) //hex or int
        let input = [stringToHex(psw), tokenAddr, amount]
        let data = await snarkjs.groth16.fullProve({in:input}, "./zk/main3_js/main3.wasm", "./zk/circuit_final.zkey")

        const vKey = JSON.parse(fs.readFileSync("./zk/verification_key.json"))
        const res = await snarkjs.groth16.verify(vKey, data.publicSignals, data.proof)

        if (res === true) {
            console.log("Verification OK")

            let pswHash = data.publicSignals[0]
            let allHash = data.publicSignals[3]

            let proof = [
                BigNumber.from(data.proof.pi_a[0]).toHexString(),
                BigNumber.from(data.proof.pi_a[1]).toHexString(),
                BigNumber.from(data.proof.pi_b[0][1]).toHexString(),
                BigNumber.from(data.proof.pi_b[0][0]).toHexString(),
                BigNumber.from(data.proof.pi_b[1][1]).toHexString(),
                BigNumber.from(data.proof.pi_b[1][0]).toHexString(),
                BigNumber.from(data.proof.pi_c[0]).toHexString(),
                BigNumber.from(data.proof.pi_c[1]).toHexString()
            ]

            await zkSafebox.withdraw(proof, pswHash, usdt.address, m(30, 18), allHash, accounts[2].address)
            console.log('withdraw done')
    
            await print()

        } else {
            console.log("Invalid proof")
        }
    })


    it('setBoxhash round2', async function () {
        let psw_old = 'abc123'
        let tokenAddr = '0x0' //hex or int
        let amount = '0' //hex or int
        let input1 = [stringToHex(psw_old), tokenAddr, amount]
        let data1 = await snarkjs.groth16.fullProve({in:input1}, "./zk/main3_js/main3.wasm", "./zk/circuit_final.zkey")

        let psw_new = 'new123'
        let input2 = [stringToHex(psw_new), tokenAddr, amount]
        let data2 = await snarkjs.groth16.fullProve({in:input2}, "./zk/main3_js/main3.wasm", "./zk/circuit_final.zkey")
        
        const vKey = JSON.parse(fs.readFileSync("./zk/verification_key.json"))
        const res1 = await snarkjs.groth16.verify(vKey, data1.publicSignals, data1.proof)
        const res2 = await snarkjs.groth16.verify(vKey, data2.publicSignals, data2.proof)

        if (res1 === true && res2 === true) {
            console.log("Verification OK")

            let pswHash1 = data1.publicSignals[0]
            let allHash1 = data1.publicSignals[3]
            let proof1 = [
                BigNumber.from(data1.proof.pi_a[0]).toHexString(),
                BigNumber.from(data1.proof.pi_a[1]).toHexString(),
                BigNumber.from(data1.proof.pi_b[0][1]).toHexString(),
                BigNumber.from(data1.proof.pi_b[0][0]).toHexString(),
                BigNumber.from(data1.proof.pi_b[1][1]).toHexString(),
                BigNumber.from(data1.proof.pi_b[1][0]).toHexString(),
                BigNumber.from(data1.proof.pi_c[0]).toHexString(),
                BigNumber.from(data1.proof.pi_c[1]).toHexString()
            ]

            let pswHash2 = data2.publicSignals[0]
            let allHash2 = data2.publicSignals[3]
            let proof2 = [
                BigNumber.from(data2.proof.pi_a[0]).toHexString(),
                BigNumber.from(data2.proof.pi_a[1]).toHexString(),
                BigNumber.from(data2.proof.pi_b[0][1]).toHexString(),
                BigNumber.from(data2.proof.pi_b[0][0]).toHexString(),
                BigNumber.from(data2.proof.pi_b[1][1]).toHexString(),
                BigNumber.from(data2.proof.pi_b[1][0]).toHexString(),
                BigNumber.from(data2.proof.pi_c[0]).toHexString(),
                BigNumber.from(data2.proof.pi_c[1]).toHexString()
            ]
            
            let boxhash = ethers.utils.solidityKeccak256(['uint256', 'address'], [pswHash2, accounts[0].address])
            
            await zkSafebox.setBoxhash(proof1, pswHash1, allHash1, proof2, pswHash2, allHash2, boxhash)
            console.log('setBoxhash done')

        } else {
            console.log("Invalid proof")
        }
    })


    it('withdraw round2', async function () {
        let psw = 'new123'

        let tokenAddr = usdt.address //hex or int
        let amount = s(m(30, 18)) //hex or int
        let input = [stringToHex(psw), tokenAddr, amount]
        let data = await snarkjs.groth16.fullProve({in:input}, "./zk/main3_js/main3.wasm", "./zk/circuit_final.zkey")

        const vKey = JSON.parse(fs.readFileSync("./zk/verification_key.json"))
        const res = await snarkjs.groth16.verify(vKey, data.publicSignals, data.proof)

        if (res === true) {
            console.log("Verification OK")

            let pswHash = data.publicSignals[0]
            let allHash = data.publicSignals[3]

            let proof = [
                BigNumber.from(data.proof.pi_a[0]).toHexString(),
                BigNumber.from(data.proof.pi_a[1]).toHexString(),
                BigNumber.from(data.proof.pi_b[0][1]).toHexString(),
                BigNumber.from(data.proof.pi_b[0][0]).toHexString(),
                BigNumber.from(data.proof.pi_b[1][1]).toHexString(),
                BigNumber.from(data.proof.pi_b[1][0]).toHexString(),
                BigNumber.from(data.proof.pi_c[0]).toHexString(),
                BigNumber.from(data.proof.pi_c[1]).toHexString()
            ]

            await zkSafebox.withdraw(proof, pswHash, usdt.address, m(30, 18), allHash, accounts[2].address)
            console.log('withdraw done')
    
            await print()

        } else {
            console.log("Invalid proof")
        }
    })


    async function print() {
        console.log('')
        for (let i=0; i<=4; i++) {
            console.log('accounts[' + i + ']',
            'usdt:', d(await usdt.balanceOf(accounts[i].address), 18), 
            'safebox usdt:', d((await zkSafebox.balanceOf(accounts[i].address, [usdt.address]))[0], 18)
			)
		}
        console.log('')
    }


    function stringToHex(string) {
        let hexStr = '';
        for (let i = 0; i < string.length; i++) {
            let compact = string.charCodeAt(i).toString(16)
            hexStr += compact
        }
        return '0x' + hexStr
    }

    function getAbi(jsonPath) {
        let file = fs.readFileSync(jsonPath)
        let abi = JSON.parse(file.toString()).abi
        return abi
    }

    async function delay(sec) {
        return new Promise((resolve, reject) => {
            setTimeout(resolve, sec * 1000);
        })
    }

    function m(num, decimals) {
        return BigNumber.from(num).mul(BigNumber.from(10).pow(decimals))
    }

    function d(bn, decimals) {
        return bn.mul(BigNumber.from(100)).div(BigNumber.from(10).pow(decimals)).toNumber() / 100
    }

    function b(num) {
        return BigNumber.from(num)
    }

    function n(bn) {
        return bn.toNumber()
    }

    function s(bn) {
        return bn.toString()
    }
})
