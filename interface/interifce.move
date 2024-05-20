module delottery::interfice{

    use sui::clock::Clock;
    use sui::coin;
    use sui::coin::TreasuryCap;
    use sui::random::Random;
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

    public  entry fun chooseWiners(clock: &Clock, lstorage:&mut LStorage, candates: &mut Candates, r: &Random, ctx: &mut TxContext){}

    public entry fun takeProfits(clock: &Clock, lstorage: &mut LStorage, candates: &mut Candates, ctx: &mut TxContext){}
    }