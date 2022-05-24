const { BigNumber } = require('ethers')
const snarkjs = require("snarkjs")
const fs = require("fs")

describe('ZkSafebox-help-test', function () {
    let accounts
    let provider
    let zkSafebox
    let nameService
    let safeboxHelp
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
        
        
        const NameService = await ethers.getContractFactory('NameService')
        nameService = await NameService.deploy()
        await nameService.deployed()
        console.log('nameService deployed:', nameService.address)
        
        
        const SafeboxHelp = await ethers.getContractFactory('SafeboxHelp')
        safeboxHelp = await SafeboxHelp.deploy(zkSafebox.address, nameService.address)
        await safeboxHelp.deployed()
        console.log('safeboxHelp deployed:', safeboxHelp.address)
    })


    it('setBoxhash', async function () {
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


    it('setName', async function () {
        await nameService.setName('George')
        console.log('setName done')
    })


    it('recharge', async function () {
        await usdt.connect(accounts[1]).approve(zkSafebox.address, m(100, 18))
        console.log('step 1 approve done')

        await safeboxHelp.connect(accounts[1]).rechargeCheckName('George', accounts[1].address, accounts[0].address, usdt.address, m(100, 18))
        console.log('step 2 rechargeCheckName done')

        await print()
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
