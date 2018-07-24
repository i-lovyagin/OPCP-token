// Using 3rd party library. Make sure it behaves as expected
const OPCPToken = artifacts.require("../contracts/OPCPToken.sol");
let opcp_token;
let result, receipt, txHash;
let src, dest;
let owner, trustee;

const totalSupply = 5 * Math.pow(10, 5);
const rate = web3.toWei(20, "finney");
const targetEarningsPct = 2;
const accountingCycleDays = 28;
const spLockedTokens = 100;
const spCommissionPct = 40;
const unlockMultiplier = 5;



contract('OPCPToken', async (accounts)=> {

    beforeEach(async () => {
        opcp_token = await OPCPToken.new(totalSupply, rate, targetEarningsPct, accountingCycleDays, spLockedTokens, spCommissionPct, unlockMultiplier);
    });

    it("Sets the total supply of 1000000 upon deployment", async()=>{
        result = await opcp_token.totalSupply.call();
        assert.equal(5 * Math.pow(10,9), result.toNumber());
    });

    it("Allocate all initial tokens to the contract admin", async()=>{
        result = await opcp_token.balanceOf.call(accounts[0]);
        assert.equal(5 * Math.pow(10,9), result.toNumber());
    });

    it("Sets the name correctly", async()=>{
        result = await opcp_token.name.call();
        assert.equal("OPCP Token", result);
    });

    it("Sets the symbol correctly", async()=>{
        result = await opcp_token.symbol.call();
        assert.equal("OPCP", result);
    });

    it("Transfers tokens from owner correctly", async()=>{
        src = accounts[0];
        dest = accounts[4];
        try{
    // throws when balance exceeded
            await opcp_token.transfer.sendTransaction(dest, 10**12, {from:src});
            assert(false);
        }
        catch (error){
            assert.isAbove(error.message.indexOf("revert"), 1, "Bad test. Expected revert on OK transaction");
        }


        result = await opcp_token.transfer(dest, 10**4, {from:src});
        // txHash = await opcp_token.transfer.sendTransaction(accounts[4], 1000, {from:account[0]});
        assert.equal(Math.pow(10, 4), (await opcp_token.balanceOf.call(dest)).toNumber());
        assert.equal(5 * Math.pow(10, 9) - Math.pow(10, 4), (await opcp_token.balanceOf.call(src)).toNumber());
        assert.equal(1, result.logs.length, "triggers one event");
        assert.equal(result.logs[0].args.from, src);
        assert.equal(result.logs[0].args.to, dest);
        assert.equal(result.logs[0].args.value.toNumber(), Math.pow(10, 4));
        console.log("transfer() gas used: ", result.receipt.gasUsed);
    });

    it("Assigns allowances correctly", async()=>{

        owner = accounts[0];
        trustee = accounts[4];

        assert.equal(true, await opcp_token.approve.call(trustee, Math.pow(10, 5), {from:owner}), "returns correct boolean");
        result = await opcp_token.approve(trustee, Math.pow(10, 5), {from:owner});
        assert.equal(1, result.logs.length, "triggers one event");
        assert.equal(result.logs[0].event, "Approval");
        assert.equal(result.logs[0].args.owner, owner);
        assert.equal(result.logs[0].args.spender, trustee);
        assert.equal(result.logs[0].args.value.toNumber(), Math.pow(10, 5));
        assert.equal(Math.pow(10, 5), await opcp_token.allowance.call(owner, trustee));
        console.log("approve() gas used: ", result.receipt.gasUsed);

    });

    it("Handles authorized token transfers", async()=>{

        owner = accounts[0];
        trustee = accounts[4];
        dest = accounts[2];

        result = await opcp_token.approve(trustee, Math.pow(10, 5), {from:owner});
        assert.equal(true, await opcp_token.transferFrom.call(owner, dest, 3 * Math.pow(10, 4), {from:trustee}), "returns correct boolean");
        result = await opcp_token.transferFrom(owner, dest,4 * Math.pow(10, 4), {from:trustee});
        assert.equal(1, result.logs.length, "Triggers one EVT");
        assert.equal(result.logs[0].event, "Transfer", "EVT: of type Transfer");
        assert.equal(result.logs[0].args.from, owner, "EVT: Payer account");
        assert.equal(result.logs[0].args.to, dest,"EVT: Payee account");
        assert.equal(result.logs[0].args.value.toNumber(), 4 * Math.pow(10, 4), "EVT: Payment amount");
        assert.equal(4 * Math.pow(10, 4), (await opcp_token.balanceOf(dest)).toNumber(), "Payee's balance increased");
        assert.equal(6 * Math.pow(10, 4), (await opcp_token.allowance.call(owner, trustee)).toNumber(), "Allowance reduced");
        console.log("transferFrom() gas used: ", result.receipt.gasUsed);

        try     {
            await opcp_token.transferFrom(owner,dest, 7 * Math.pow(10, 4), {from:trustee});
            assert.equal(false, true, "Exception should have been thrown. Allowance has been exceeded by trustee");
        }
        catch (err) {
            assert.isAbove(err.message.indexOf("revert"), 1, "Revert triggered exception");
        }

        result = await opcp_token.approve(trustee, Math.pow(10, 10), {from:owner});
        try     {
            await opcp_token.transferFrom(owner,dest, Math.pow(10, 10) - Math.pow(10, 4) + 1, {from:trustee});
            assert.equal(false, true, "Unexpectedly no exception thrown. Delegated transfer source funds exceeded");
        }
        catch (err) {
            assert.isAbove(err.message.indexOf("revert"), 1, "Revert triggered exception");
        }
    });
});
