var OPCPToken = artifacts.require("./OPCPToken.sol");
var OPCPTokenSale = artifacts.require("./OPCPTokenSale.sol");

const totalSupply = 5 * Math.pow(10, 5);
const rate = web3.toWei(20, "finney");
const targetEarningsPct = 2;
const accountingCycleDays = 28;
const spLockedTokens = 100;
const spCommissionPct = 40;
const unlockMultiplier = 5;

const initFunding = 200000;
const ownerPct = 10;

module.exports = function(deployer, network, accounts) {
    deployer.deploy(OPCPToken, totalSupply, rate, targetEarningsPct, accountingCycleDays, spLockedTokens, spCommissionPct, unlockMultiplier).then(function() {
        var addr = accounts[9];
        console.log("--------------------Using Wallet address: ------------", addr);
    
        return deployer.deploy(OPCPTokenSale, addr, OPCPToken.address,initFunding, ownerPct);
    });
};
  
// bug in js. async... await syntax results in missing network info
/*
const fs = require('fs');

module.exports = async(deployer, accounts) => {
	await deployer.deploy(OPCPToken, 5 * Math.pow(10, 5), web3.toWei(20, "finney"));
	console.log("Token Deployed at: ", OPCPToken.address);
	await deployer.deploy(OPCPTokenSale, "0xc01323Ac26dE749e47CaD24c884326719e4E99CD", OPCPToken.address);
	console.log("Sale Deployed at: ", OPCPTokenSale.address, " with token at: ", OPCPToken.address);

	const metaDataFile = `${__dirname}/../build/contracts/OPCPTokenSale.json`;
	const metaData = require(metaDataFile);
	metaData.networks[deployer.network_id] = {};
	metaData.networks[deployer.network_id].address = OPCPTokenSale.address;
	fs.writeFileSync(metaDataFile, JSON.stringify(metaData, null, 4))

	return OPCPTokenSale;
}
*/