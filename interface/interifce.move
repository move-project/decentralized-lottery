module delottery::interfice{

    use sui::clock::Clock;
    use sui::coin;
    use sui::coin::TreasuryCap;
    use sui::sui::SUI;
    use lending_core::incentive_v2::IncentiveFundsPool;
    use lending_core::pool::Pool;
    use lending_core::storage::Storage;
    use oracle::oracle::PriceOracle;
    use dlottery::dlottery::{DLOTTERY, LStorage, Candates, NaviAccount};
    use lending_core::incentive::{Incentive as IncentiveV1};
    use lending_core::incentive_v2::{Incentive as IncentiveV2};

    public entry fun createPool(treasuryCap: &mut TreasuryCap<DLOTTERY>, clock: &Clock, ctx: &mut TxContext){}

    public entry fun deposit(mut payment: coin::Coin<SUI>,  amount: u64, lstorage: &mut LStorage, candate: &mut Candates, clock: &Clock, ctx: &mut TxContext){}

    public entry fun withdraw(amount: u64, mut shares: coin::Coin<DLOTTERY>, lstorage: &mut LStorage, candate: &mut Candates, clock: &Clock, ctx: &mut TxContext){}

    public entry fun depositToNavi(clock: &Clock, lstorage:&mut LStorage, me: &NaviAccount, storage: &mut Storage, pool: &mut Pool<SUI>, incentive_v1: &mut IncentiveV1, incentive_v2: &mut IncentiveV2, ctx: &mut TxContext){}

    public entry fun withdrawFromNavi(clock: &Clock, lstorage:&mut LStorage, incentive_v1: &mut IncentiveV1, incentive_v2: &mut IncentiveV2, funds_pool: &mut IncentiveFundsPool<SUI>, pool: &mut Pool<SUI>, storage: &mut Storage, me: &NaviAccount, oracle: &PriceOracle, ctx: &mut TxContext){}

    public entry fun takeProfits(clock: &Clock, lstorage: &mut LStorage, candates: &mut Candates, ctx: &mut TxContext){}

    //events
    public struct PoolCreated has copy, drop{
        pool_id: ID,
        pool_SUI_value: u64,
        shares_supply: u64,
        admin: address
    }
    public struct CustomerDeposited has copy, drop{
        customer: address,
        SUI_input: u64,
        shares_output: u64,
        current_pool_SUI_profits: u64,
        current_pool_shares: u64,
        cueernt_customer_numbers: u64
    }
    public struct CustomerWithdrawed has copy, drop{
        customer: address,
        SUI_output: u64,
        shares_input: u64,
        current_pool_SUI_profits: u64,
        current_pool_shares: u64,
        cueernt_customer_numbers: u64
    }
    public struct DepositedToNavi has copy, drop{
        timeStamp: u64,
        SUI_value: u64,
    }
    public struct WithdrawedFromNavi has copy, drop{
        timeStamp: u64,
        SUI_value: u64,
        pure_profits: u64
    }
    public struct ProfitsTaken has copy, drop{
        winner: address,
        rewards: u64
    }
}