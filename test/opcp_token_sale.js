const OPCPToken = artifacts.require("../contracts/OPCPToken.sol");
const OPCPTokenSale = artifacts.require("../contracts/OPCPTokenSale.sol");
let token;
let sale;


const tokenSupply = 5 * Math.pow(10, 5);
const tokenPrice = web3.utils.toWei("20", "finney");
const targetEarningsPct = 2;
const accountingCycleDays = 28;
const spLockedTokens = 100;
const spCommissionPct = 40;
const unlockMultiplier = 5;

const initFunding = 200000;
const ownerReservePct = 10;


contract('OPCPTokenSale and OPCPToken', async (accounts)=> {

    const owner = accounts[0];
    const inv1 = accounts[1];
    const wallet = accounts[9];


    let result, bal1, bal2, bal3, bal4, toks1, toks2, toks3, toks4;
    let x1, x2, x3, x4, x5, x6, x7, x8;

    
    beforeEach(async () => {
        token = await OPCPToken.new(tokenSupply, tokenPrice, targetEarningsPct, accountingCycleDays, spLockedTokens, spCommissionPct, unlockMultiplier);
        sale = await OPCPTokenSale.new(wallet, token.address, initFunding, ownerReservePct);
        // console.log("Token: ", token.address," Sale: ", sale.address," Wallet: ", wallet);
        // await token.setStore(sale.address, ownerReservePct);  // 10% allocated to owner
    });

    it("Correctly allocates tokens for sale and owner tokens", async()=>{
        assert.equal((await token.balanceOfAdj.call(owner)).toNumber(), tokenSupply * ownerReservePct / 100);
        assert.equal((await token.balanceOfAdj.call(sale.address)).toNumber(), tokenSupply * (100 - ownerReservePct) / 100);
        assert.equal((await sale.forSale.call()).toNumber(), tokenSupply * (100 - ownerReservePct) / 100);
    });

    it("Handles token sale accounting correctly", async()=>{
        // token price 20 finney. 2 ether buys 400 tokens
        var pricePaid = 3.5;

        bal1 = (await web3.eth.getBalance(wallet));
        bal2 = (await web3.eth.getBalance(inv1));
        toks1 = (await token.balanceOfAdj.call(inv1));
        toks3 = (await token.balanceOfAdj.call(sale.address));

        result = await sale.buyTokens({from:inv1, value:web3.utils.toWei(String(pricePaid), "ether")});

        bal3 = (await web3.eth.getBalance(wallet));
        bal4= (await web3.eth.getBalance(inv1));
        toks2 = (await token.balanceOfAdj.call(inv1));
        toks4 = (await token.balanceOfAdj.call(sale.address));
        x1 = (await web3.eth.getTransaction(result.receipt.transactionHash)).gasPrice;
        x2 = result.receipt.gasUsed;
        x3 = parseInt(web3.utils.fromWei(String(bal3), "gwei")) - parseInt(web3.utils.fromWei(String(bal1), "gwei"));
        x4 = parseInt(web3.utils.fromWei(String(bal2), "gwei")) - parseInt(web3.utils.fromWei(String(bal4), "gwei"));
        x5 = parseInt(web3.utils.fromWei(web3.utils.toWei(String(pricePaid), "ether"), "gwei")); // cost of tokens
        x6 = parseInt(web3.utils.fromWei(String(x1 * x2), "gwei"));  //gas
        x7 = toks2 - toks1; // token holdings change
        x8 = parseInt(web3.utils.toWei(String(pricePaid), "ether"))/tokenPrice;
        assert.equal(x4, x5 + x6,"Buyer's balance reduced by the cost of tokens and gas");
        assert.equal(x7, x8 ,"Buyer's token holdings increased by the number of bought tokens");
        assert.equal(x3, x5 ,"Wallet balance increased by the cost of sold tokens");
        assert.equal(x7, toks3 - toks4, "Contract reserve of tokens reduced by the number of sold tokens");
        console.log("sold tokens: ", x8);
        console.log("gas in gwei: ", x6);
    });
});
