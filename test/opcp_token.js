const OPCPToken = artifacts.require("../contracts/OPCPToken.sol");
let opcp_token;

const totalSupply = 5 * Math.pow(10, 5);
const rate = web3.toWei(20, "finney");
const targetEarningsPct = 2;
const accountingCycleDays = 28;
const spLockedTokens = 100;
const spCommissionPct = 40;
const unlockMultiplier = 5;


contract('OPCPToken', async (accounts)=> {

    const owner = accounts[0];
    const sp1 = accounts[1];
    const sp2 = accounts[2];
    const sp3 = accounts[3];
    const cus1 = accounts[4];
    const cus2 = accounts[5];

    let result, res, txHash, bal1, bal2, bal3, bal4, src, dest, prov1, prov2, tmp, cust;

    beforeEach(async () => {
        opcp_token = await OPCPToken.new(totalSupply, rate, targetEarningsPct, accountingCycleDays, spLockedTokens, spCommissionPct, unlockMultiplier);
    });

    it("Creates default provider", async()=>{
        result = await  opcp_token.providers.call(owner);
        prov1 = {
          description: result[0],
          nextSettlement: new Date(result[1].toNumber() * 1000),
          lockedTokens: result[2].toNumber(),
          active: result[3],
          earnings: result[4].toNumber(),
          cycleEarnings: result[5].toNumber()
        }
        assert.equal(prov1.description, "Default provider");
        assert.isAbove(prov1.nextSettlement.getFullYear(), 2900, "Next settlement isn't any time soon");
        assert(prov1.active, "Invalid active status");
    });

    it("Registers a new service provider and initializes the main distribution cycle", async()=>{
        result = await opcp_token.transfer(sp1, 6  * Math.pow(10, 6));
        console.log("Transfer gas used: ", result.receipt.gasUsed);
        try{
            await opcp_token.registerSP("SP2 Provider w 6MT", {from:sp2});
            assert(false);
        }
        catch (error){
            assert.isAbove(error.message.indexOf("revert"), 1, "Bad test. Expected exception on valid registration");
        }
        
        result = await opcp_token.registerSP("SP1 Provider w 6MT", {from:sp1});
        assert.equal(1, result.logs.length, "Triggers one EVT");
        assert.equal(result.logs[0].event, "ProviderRegistration", "EVT: of type ProviderRegistration");
        assert.equal(result.logs[0].args.provider, sp1, "EVT: New provider address");
        assert.equal(result.logs[0].args.lockedTokens.toNumber(), 1000000, "EVT: Locked tokens count");
        console.log("registerSP() gas used: ", result.receipt.gasUsed);

        result = await  opcp_token.providers.call(sp1);
        prov1 = {
          description: result[0],
          nextSettlement: result[1].toNumber() * 1000,
          lockedTokens: result[2].toNumber(),
          active: result[3],
          earnings: result[4].toNumber(),
          cycleEarnings: result[5].toNumber()
        }
        assert.equal(prov1.description, "SP1 Provider w 6MT");
        tmp = prov1.nextSettlement - (new Date()).getTime();  // in milliseconds
        assert.equal(Math.floor(tmp / 1000 / 60) + 1, 28*24*60, "Next settlement in 4 weeks");
        assert.equal(prov1.lockedTokens, 1000000, "Locked sp tokens");
        assert(prov1.active, "Invalid active status");
        assert.equal(prov1.earnings, 0, "Cumulative earnings");
        assert.equal(prov1.cycleEarnings, 0, "Cycle earnings");

        result = (await  opcp_token.cycleEarnings.call()).toNumber();
        assert.equal(result,0);

        result = await  opcp_token.nextDistribution.call();
        tmp = result.toNumber() * 1000 - (new Date()).getTime();
        assert.equal(Math.floor(tmp / 1000 / 60) + 1, 28*24*60, "Next contract distribution is in 4 weeks");
    });

    it("Unregisters an active service provider", async()=>{
        result = await opcp_token.transfer(sp1, 6  * Math.pow(10, 6));
        result = await opcp_token.registerSP("SP1 Provider w 6MT", {from:sp1});
        
        try{
            await opcp_token.unregisterSP({from:sp2});
            assert(false);
        }
        catch (error){
            assert.isAbove(error.message.indexOf("revert"), 1, "Bad test. Expected exception on valid un-registration");
        }

        try{
            await opcp_token.unregisterSP({from:owner});
            assert(false);
        }
        catch (error){
            assert.isAbove(error.message.indexOf("revert"), 1, "Bad test. Expected exception on valid un-registration");
        }

        result = await opcp_token.unregisterSP({from:sp1});

        assert.equal(3, result.logs.length, "Triggers three EVTs");
        assert.equal(result.logs[0].event, "Burn", "EVT: of type Burn");
        assert.equal(result.logs[1].event, "Transfer", "EVT: of type Transfer");
        assert.equal(result.logs[2].event, "ProviderCancelRegistration", "EVT: of type ProviderCancelRegistration");
        assert.equal(result.logs[2].args.provider, sp1, "EVT: Canceling provider address");
        assert.equal(result.logs[2].args.finalSettlement.toNumber(), 0, "EVT: Final Settlement amount");
        assert.equal(result.logs[2].args.burnedTokens.toNumber(), Math.pow(10, 6), "EVT: Burned Tokens");
        console.log("UN-registerSP() gas used: ", result.receipt.gasUsed);

        result = await  opcp_token.providers.call(sp1);
        prov1 = {
          description: result[0],
          nextSettlement: result[1].toNumber() * 1000,
          lockedTokens: result[2].toNumber(),
          active: result[3],
          earnings: result[4].toNumber(),
          cycleEarnings: result[5].toNumber()
        }
        assert(!prov1.active, "Invalid active status");
    });


    it("Accepts direct customer deposits", async()=>{
        result = await opcp_token.transfer(sp1, 6  * Math.pow(10, 6));
        result = await opcp_token.registerSP("SP1 Provider w 6MT", {from:sp1});
        result = await opcp_token.customerDirectDeposit(sp2, {from:cus1, value:web3.toWei(2, "ether")});
        console.log("CustomerDirectDeposit() gas used: ", result.receipt.gasUsed);

        result = await  opcp_token.customers.call(cus1);
        cust = {
          provider: result[0],
          balance: web3.fromWei(result[1].toNumber(), "ether")
        };
        assert.equal(cust.provider, owner);
        assert.equal(cust.balance, 2);

        result = await opcp_token.customerDirectDeposit(sp1, {from:cus2, value:web3.toWei(3, "ether")});
        result = await  opcp_token.customers.call(cus2);
        cust = {
          provider: result[0],
          balance: web3.fromWei(result[1].toNumber(), "ether")
        };
        assert.equal(cust.provider, sp1);
        assert.equal(cust.balance, 3);
    });

    it("Accepts customer deposits via provider", async()=>{
        result = await opcp_token.transfer(sp1, 6  * Math.pow(10, 6));
        result = await opcp_token.registerSP("SP1 Provider w 6MT", {from:sp1});
        
        try{   // inactive service provider test
            await opcp_token.customerDeposit(cus1, {from:sp2, value:web3.toWei(2, "ether")});
            assert(false);
        }
        catch (error){
            assert.isAbove(error.message.indexOf("revert"), 1, "Bad test. Expected exception on valid service provider deposit");
        }

        result = await opcp_token.customerDeposit(cus1, {from:sp1, value:web3.toWei(2, "ether")});
        console.log("CustomerDeposit() gas used: ", result.receipt.gasUsed);
        result = await  opcp_token.customers.call(cus1);
        cust = {
          provider: result[0],
          balance: web3.fromWei(result[1].toNumber(), "ether")
        };
        assert.equal(cust.provider, sp1);
        assert.equal(cust.balance, 2);
    });

    it("Handles direct customer withdrawals", async()=>{
        result = await opcp_token.transfer(sp1, 6  * Math.pow(10, 6));
        result = await opcp_token.registerSP("SP1 Provider w 6MT", {from:sp1});
        result = await opcp_token.customerDirectDeposit(sp1, {from:cus1, value:web3.toWei(5, "ether")});
        try{   // over the limit withdrawal
            await opcp_token.customerDirectWithdrawal(web3.toWei(10, "ether"), {from:cus1});
            assert(false);
        }
        catch (error){
            assert.isAbove(error.message.indexOf("revert"), 1, "Bad test. Over the limit withdrawal");
        }

        result = await opcp_token.customerDirectWithdrawal(web3.toWei(3, "ether"), {from:cus1});
        assert.equal(1, result.logs.length, "Triggers one EVT");
        assert.equal(result.logs[0].event, "CustomerWithdrawal", "EVT: of type CustomerWithdrawal");
        assert.equal(result.logs[0].args.customer, cus1, "EVT: Customer address");
        assert.equal(result.logs[0].args.provider, sp1, "EVT: Provider address");
        assert.equal(result.logs[0].args.fromAddress, cus1, "EVT: Source address");
        assert.equal(web3.fromWei(result.logs[0].args.amount.toNumber(), "ether"), 3, "EVT: Amount");
        console.log("CustomerDirectWithdrawal() gas used: ", result.receipt.gasUsed);

        result = await  opcp_token.customers.call(cus1);
        cust = {
          provider: result[0],
          balance: result[1].toNumber()
        };
        assert.equal(web3.fromWei(cust.balance, "ether"), 2, "Customer balance after withdrawal");

        result = await opcp_token.customerDirectWithdrawal(cust.balance, {from:cus1});
        result = await  opcp_token.customers.call(cus1);
        cust = {
            provider: result[0],
            balance: web3.fromWei(result[1].toNumber(), "ether")
        };
        assert.equal(cust.balance, 0, "Customer balance after withdrawal");
    });

    it("Handles customer withdrawals by provider", async()=>{
        result = await opcp_token.transfer(sp1, 6  * Math.pow(10, 6));
        result = await opcp_token.registerSP("SP1 Provider w 6MT", {from:sp1});
        result = await opcp_token.customerDirectDeposit(sp1, {from:cus1, value:web3.toWei(5, "ether")});

        try{   // unauthorized provider request
            await opcp_token.customerWithdrawal(cus1, web3.toWei(1, "ether"), {from:sp2});
            assert(false);
        }
        catch (error){
            assert.isAbove(error.message.indexOf("revert"), 1, "Bad test. Unauthorized provider request");
        }

        try{   // over the limit withdrawal
            await opcp_token.customerWithdrawal(cus1, web3.toWei(10, "ether"), {from:sp1});
            assert(false);
        }
        catch (error){
            assert.isAbove(error.message.indexOf("revert"), 1, "Bad test. Exceeded withdrawal limit");
        }

        result = await opcp_token.customerWithdrawal(cus1, web3.toWei(3, "ether"), {from:sp1});
        assert.equal(1, result.logs.length, "Triggers one EVT");
        assert.equal(result.logs[0].event, "CustomerWithdrawal", "EVT: of type CustomerWithdrawal");
        assert.equal(result.logs[0].args.customer, cus1, "EVT: Customer address");
        assert.equal(result.logs[0].args.provider, sp1, "EVT: Provider address");
        assert.equal(result.logs[0].args.fromAddress, sp1, "EVT: Source address");
        assert.equal(web3.fromWei(result.logs[0].args.amount.toNumber(), "ether"), 3, "EVT: Amount");
        console.log("CustomerWithdrawal() gas used: ", result.receipt.gasUsed);

        result = await  opcp_token.customers.call(cus1);
        cust = {
          provider: result[0],
          balance: web3.fromWei(result[1].toNumber(), "ether")
        };
        assert.equal(cust.balance, 2, "Customer balance after withdrawal");
    });


    it("Handles customer session", async()=>{
        result = await opcp_token.transfer(sp1, 6  * Math.pow(10, 6));
        result = await opcp_token.registerSP("SP1 Provider w 6MT", {from:sp1});
        result = await opcp_token.customerDirectDeposit(sp1, {from:cus1, value:web3.toWei(1, "ether")})

        try{   // customer account with zero balance
            await opcp_token.customerSession(cus2, web3.toWei(1, "ether"), {from:sp1});
            assert(false);
        }
        catch (error){
            assert.isAbove(error.message.indexOf("revert"), 1, "Bad test. Zero balance account session");
        }
        
        result = await  opcp_token.providers.call(sp1);
        prov1 = {
          description: result[0],
          nextSettlement: result[1].toNumber() * 1000,
          lockedTokens: result[2].toNumber(),
          active: result[3],
          earnings: result[4].toNumber(),
          cycleEarnings: result[5].toNumber()
        }
        bal1 = prov1.cycleEarnings;
        bal2 = (await  opcp_token.cycleEarnings.call()).toNumber();

        result = await opcp_token.customerSession(cus1, web3.toWei(2, "ether"), {from:sp1});

        assert.equal(1, result.logs.length, "Triggers one EVT");
        assert.equal(result.logs[0].event, "CustomerSession", "EVT: of type CustomerSession");
        assert.equal(result.logs[0].args.customer, cus1, "EVT: Customer address");
        assert.equal(result.logs[0].args.provider, sp1, "EVT: Provider address");
        assert.equal(result.logs[0].args.fromAddress, sp1, "EVT: Source address");
        assert.equal(web3.fromWei(result.logs[0].args.amount.toNumber(), "ether"), 2, "EVT: Amount");
        console.log("CustomerSession() gas used: ", result.receipt.gasUsed);

        result = await  opcp_token.providers.call(sp1);
        prov1 = {
          description: result[0],
          nextSettlement: result[1].toNumber() * 1000,
          lockedTokens: result[2].toNumber(),
          active: result[3],
          earnings: result[4].toNumber(),
          cycleEarnings: result[5].toNumber()
        }
        bal3 = prov1.cycleEarnings;
        bal4 = (await  opcp_token.cycleEarnings.call()).toNumber();

        assert.equal(bal3 - bal1, web3.toWei(2, "ether"), "Provider's running total of customer sessions");
        assert.equal(bal4 - bal2, web3.toWei(2, "ether"), "Contract's running total of customer sessions");

    });
});
