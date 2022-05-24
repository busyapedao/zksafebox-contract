const hre = require('hardhat')
const fs = require('fs')
const { BigNumber } = require('ethers')


// usdt deployed: 0x2F4117b7CCb0605C7BC40Dd7F6a023827fBFB840
// busd deployed: 0xA2F3f13A599fC56a4965Bb2c306a42313c24217a
// zkSafebox deployed: 0x0542E32040bc70519C3cFaed438072050F1Ad977
// nameService deployed: 0xe2De4D38DB1B04d32011dC3eC0Af7420de18DCD2
// safeboxHelp deployed: 0x7A7630c80d44E87402afd11C939C03F43b4785f4

async function main() {
	const accounts = await hre.ethers.getSigners()
	const account1 = '0x05e6959423FFb22e04D873bB1013268aa34E24B8'

	// const MockERC20 = await ethers.getContractFactory('MockERC20')
	// const usdt = await MockERC20.deploy('MockUSDT', 'USDT')
	// await usdt.deployed()
	// console.log('usdt deployed:', usdt.address)
	// await usdt.mint(accounts[0].address, m(100000, 18))
	// console.log('usdt mint to accounts[0]', d(await usdt.balanceOf(accounts[0].address), 18))
	// await usdt.mint(account1, m(100000, 18))
	// console.log('usdt mint to account1', d(await usdt.balanceOf(account1), 18))


	// const busd = await MockERC20.deploy('MockBUSD', 'BUSD')
	// await busd.deployed()
	// console.log('busd deployed:', busd.address)
	// await busd.mint(accounts[0].address, m(100000, 18))
	// console.log('busd mint to accounts[0]', d(await busd.balanceOf(accounts[0].address), 18))
	// await busd.mint(account1, m(100000, 18))
	// console.log('busd mint to account1', d(await busd.balanceOf(account1), 18))

	
	const ZkSafebox = await ethers.getContractFactory('ZkSafebox')
	const zkSafebox = await ZkSafebox.deploy()
	await zkSafebox.deployed()
	console.log('zkSafebox deployed:', zkSafebox.address)
	
	
	const NameService = await ethers.getContractFactory('NameService')
	const nameService = await NameService.deploy()
	await nameService.deployed()
	console.log('nameService deployed:', nameService.address)
	
	
	const SafeboxHelp = await ethers.getContractFactory('SafeboxHelp')
	const safeboxHelp = await SafeboxHelp.deploy(zkSafebox.address, nameService.address)
	await safeboxHelp.deployed()
	console.log('safeboxHelp deployed:', safeboxHelp.address)

	console.log('done')
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

main()
	.then(() => process.exit(0))
	.catch(error => {
		console.error(error);
		process.exit(1);
	});