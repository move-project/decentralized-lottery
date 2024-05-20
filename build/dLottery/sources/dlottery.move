
/// Module: dlottery
module dlottery::dlottery {
    use std::option;
    use std::vector;
    use sui::balance;
    use sui::balance::Balance;
    use sui::clock;
    use sui::clock::Clock;
    use sui::coin;
    use sui::coin::{TreasuryCap, DenyCap, CoinMetadata};
    use sui::event;
    use sui::object;
    use sui::object::UID;
    use sui::random;
    use sui::random::{Random, new_generator};
    use sui::sui::SUI;
    use sui::table;
    use sui::transfer;
    use sui::tx_context::{TxContext, sender};
///from module NAVI Protocol
    use lending_core::account::{AccountCap};
    use lending_core::pool::{Pool};
    use lending_core::incentive::{Incentive as IncentiveV1};
    use lending_core::incentive_v2::{Self as incentive_v2, Incentive as IncentiveV2, IncentiveFundsPool};
    use lending_core::lending;
    use lending_core::storage::{Storage};
    use oracle::oracle::PriceOracle;


    // create a storage to store the Sui
    public struct LStorage has key{
        id: UID,
        profits: Balance<SUI>,
        currentSupply: Balance<DLOTTERY>,
        timeA: u64,
        timeB: u64,
        totalValue: u64, // the value of sui, which is used to caculate the profits after staking
        isStaking: bool,
        admin: address
    }
    //otw, also the name of the shares
    public struct DLOTTERY has drop{}
    // the struce used to store the candidates' addresses
    public struct Candates has key, store{
        id: UID,
        candates: table::Table<u64, Candate>,
        customers: vector<address>,
        winers: table::Table<address, u64>,
        totalNumber: u64,
        admin: address,
        lsCreated: bool
    }
    // the amount of shares the owner has
    public struct Candate has store, drop{
        address: address,
        shares: u64,
    }
    //NAVI Account
    public struct NaviAccount has store, key{
        id: UID,
        naviAccount: AccountCap
    }

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

    // 3days
    const THREEDAYS: u64 = 259200000;
    // 7 days
    const SEVENDAYS: u64 = 604800000;
    // total number of shares
    const TOTALSHARES: u64 = 10000;
    // sui asset_id
    const SUIASSETID: u8 = 0;

    //errors
    // the Sui is not enough to buy one lottery
    const SUINOTENOUGH: u64 = 0;
    // the amount want to deposit is too large
    const TOOMANYSHARES: u64 = 1;
    // the owner doesn't exsist in the table
    const OWNERNOTEXSISTS: u64 = 2;
    // ont the admin
    const NOTADMIN: u64 = 3;
    // time invalid
    const  TIMENOTVALID: u64 = 4;
    // during staking
    const DURINGSTAKING: u64 = 5;


    fun init(otw: DLOTTERY, ctx: &mut TxContext){
        // create the regulated currency with the deny list
        let treasuryCap: TreasuryCap<DLOTTERY>;
        let denyCap: DenyCap<DLOTTERY>;
        let metadata: CoinMetadata<DLOTTERY>;
        (treasuryCap, denyCap, metadata) = coin::create_regulated_currency(
            otw,
            0, //1 lc_coin = 0.1 Sui = 10000000 * SUI decimal
            b"LT",
            b"Lottery Coin",
            b"the shares used to convert and exchange Sui",
            option::none(),
            ctx
        );
        // handle the coin
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(denyCap, sender(ctx));
        // transfer to the admin
        transfer::public_transfer(treasuryCap, sender(ctx));

        // initialize the struct candates and share it
        let candates = Candates{
            id: object::new(ctx),
            candates: table::new(ctx),
            winers: table::new(ctx),
            customers: vector::empty<address>(),
            totalNumber: 0,
            admin: sender(ctx),
            lsCreated: false
        };
        transfer::public_share_object(candates);

        // create the NAVI account
        let cap = lending::create_account(ctx);
        transfer::public_share_object(NaviAccount{id: object::new(ctx), naviAccount: cap})

    }

    // the function used to ceate pool by the admin
    public entry fun createPool(treasuryCap: &mut TreasuryCap<DLOTTERY>, clock: &Clock, ckey: &Candates, ctx: &mut TxContext){
        // make sure is the admin and can only be called for once
        assert!(ckey.lsCreated == false && ckey.admin == sender(ctx), NOTADMIN);
        // update the state
        ckey.lsCreated == true;
        // init the LStorage
        let mut lstorage = LStorage{ //mut
            id: object::new(ctx),
            profits: balance::zero<SUI>(),
            currentSupply: balance::zero<DLOTTERY>(),
            timeA: clock::timestamp_ms(clock),
            timeB: clock::timestamp_ms(clock) + THREEDAYS, //+ 3days
            totalValue: 0,
            isStaking: false,
            admin: sender(ctx)
        };
        let ls_id = object::id(&lstorage);

        // the total supply of the lottery is 100
        let lc_coin = coin::mint(treasuryCap, TOTALSHARES, ctx);
        // put lottery all in the storage
        coin::put(&mut lstorage.currentSupply, lc_coin);
        // share the storage so everyone can exchange the lottery
        transfer::share_object(lstorage);

        event::emit(PoolCreated{pool_id: ls_id, pool_SUI_value: 0, shares_supply: TOTALSHARES, admin: sender(ctx)});
    }

    // the function used to buy the lotteries and return the shares(LT) to the buyers
    // amount is the number of sahres customer want to buy, it should be an uint
    public entry fun deposit(mut payment: coin::Coin<SUI>,  amount: u64, lstorage: &mut LStorage, candate: &mut Candates, clock: &Clock, ctx: &mut TxContext){
        // make sure time is valid, assert if invalid
        isValidTime(lstorage, clock);
        // make sure is not during staking
        assert!(lstorage.isStaking == false, DURINGSTAKING);
        // the maxium of the number of shares of a customer can buy is 20, and haven't been sold out
        assert!(amount <= 20 && balance::value(&lstorage.currentSupply) > 0, TOOMANYSHARES);
        // should have enough Sui, value is the number of the coin, here at least 0.1 sui means 10 ^ 7
        assert!(coin::value(&payment) >= 10000000 * amount, SUINOTENOUGH);

        let coin_input = coin::split(&mut payment, amount * 10000000, ctx); //10^7

        // if this is a new customer:
        if (!vector::contains(& candate.customers, &sender(ctx))){
            // update the customers[], start from [0]
            vector::push_back(&mut candate.customers, sender(ctx));
            // add to the table, start from <0, Candate>
            table::add(&mut candate.candates, candate.totalNumber,
                Candate{address: sender(ctx), shares: amount});
            // increase the total number
            candate.totalNumber = candate.totalNumber + 1;
            //increase the total value
            lstorage.totalValue = lstorage.totalValue + coin::value(&coin_input);
        }else {
            // find the index of the customer
            let (_, _index) = vector::index_of(&candate.customers, &sender(ctx));
            let _customer = table::borrow_mut(&mut candate.candates, _index);
            _customer.shares = _customer.shares + amount;
            //increase the total value
            lstorage.totalValue = lstorage.totalValue + coin::value(&coin_input);
        };

        coin::put(&mut lstorage.profits, coin_input);
        let lottery = coin::take(&mut lstorage.currentSupply, amount, ctx);
        transfer::public_transfer(payment, sender(ctx));
        transfer::public_transfer(lottery, sender(ctx));

        event::emit(CustomerDeposited{
            customer: sender(ctx),
            SUI_input: amount * 10000000,
            shares_output: amount,
            current_pool_SUI_profits: lstorage.totalValue,
            current_pool_shares: balance::value(&lstorage.currentSupply),
            cueernt_customer_numbers: candate.totalNumber
        });
    }

    //can only be called during the period of 3 days
    public entry fun withdraw(amount: u64, mut shares: coin::Coin<DLOTTERY>, lstorage: &mut LStorage, candate: &mut Candates, clock: &Clock, ctx: &mut TxContext){
        // make sure the owner exsists
        assert!(vector::contains(&candate.customers, &sender(ctx)), OWNERNOTEXSISTS);
        //make sure the time is valid or assert
        isValidTime(lstorage, clock);
        // make sure is not during staking
        assert!(lstorage.isStaking == false, DURINGSTAKING);

        // get the number of the shares belongs to the owner
        let (_, _index) = vector::index_of(&candate.customers, &sender(ctx));
        let mut _customer = table::borrow_mut(&mut candate.candates, _index);
        // the amount should be <= the owner's total amount
        assert!(amount <= _customer.shares, TOOMANYSHARES);

        let sui = coin::take(&mut lstorage.profits, amount * 10000000, ctx);

        lstorage.totalValue = lstorage.totalValue - coin::value(&sui);
        _customer.shares  = _customer.shares - amount;
        if(_customer.shares == 0){
            // remove the customer from both customers[] and table
            if(_index == candate.totalNumber - 1){ //if is the last one
                //remove directly
                vector::remove(&mut candate.customers, _index);
                table::remove(&mut candate.candates, _index);
                // update the total number
                candate.totalNumber = candate.totalNumber - 1;
            }else {
                // get the address of the one to be removed and the last one from the customers[]
                let mut _addressToBeRemoved = vector::borrow_mut(&mut candate.customers, _index);
                let _addressOfTheLastOne = vector::borrow_mut(&mut candate.customers, candate.totalNumber - 1);
                _addressToBeRemoved = _addressOfTheLastOne;
                // then remove the last one in the customers[]
                vector::remove(&mut candate.customers, candate.totalNumber - 1);
                // update the table with the same method
                let _customerOfTheLastOne = table::borrow_mut(&mut candate.candates, candate.totalNumber - 1);
                // replace
                _customer = _customerOfTheLastOne;
                // remove the last one
                table::remove(&mut candate.candates, candate.totalNumber - 1);
                // update the total number
                candate.totalNumber = candate.totalNumber - 1;
            }
        };
        let sharesInput = coin::split(&mut shares, amount, ctx);
        coin::put(&mut lstorage.currentSupply, sharesInput);
        transfer::public_transfer(sui, sender(ctx));
        transfer::public_transfer(shares, sender(ctx));

        event::emit(CustomerWithdrawed{
            customer: sender(ctx),
            SUI_output: amount * 10000000,
            shares_input: amount,
            current_pool_SUI_profits: lstorage.totalValue,
            current_pool_shares: balance::value(&lstorage.currentSupply),
            cueernt_customer_numbers: candate.totalNumber
        });
    }

    // the function for NAVI deposit, only admin can call
    public entry fun depositToNavi(clock: &Clock, lstorage:&mut LStorage, me: &NaviAccount, storage: &mut Storage, pool: &mut Pool<SUI>, incentive_v1: &mut IncentiveV1, incentive_v2: &mut IncentiveV2, ctx: &mut TxContext){
        //make sure time is valid, this should be during the 7 days
        !isValidTime(lstorage, clock);
        // make sure is not during staking
        assert!(lstorage.isStaking == false, DURINGSTAKING);
        // make sure is the admin
        assert!(sender(ctx) == lstorage.admin, NOTADMIN);
        // make sure the balance is not 0
        assert!(balance::value(&lstorage.currentSupply) == 0, SUINOTENOUGH);

        //update the symbol
        lstorage.isStaking == true;
        // update the timeStamp manually
        lstorage.timeA = clock::timestamp_ms(clock);
        lstorage.timeB = lstorage.timeA + SEVENDAYS;

        // place the sui in th navi pool, do not update the totalvalue because it will be used to calculate the profits, l sui is used to pay the gas fee
        incentive_v2::deposit_with_account_cap(clock, storage, pool, SUIASSETID, coin::take(&mut lstorage.profits, lstorage.totalValue - 100000000, ctx), incentive_v1, incentive_v2, &me.naviAccount);

        event::emit(DepositedToNavi{
            timeStamp: clock::timestamp_ms(clock),
            SUI_value: lstorage.totalValue - 100000000
        });
    }

    // withdraw from NAVI
    public entry fun withdrawFromNavi(clock: &Clock, lstorage:&mut LStorage, incentive_v1: &mut IncentiveV1, incentive_v2: &mut IncentiveV2, funds_pool: &mut IncentiveFundsPool<SUI>, pool: &mut Pool<SUI>, storage: &mut Storage, me: &NaviAccount, oracle: &PriceOracle, candates: &mut Candates, r: &Random, ctx: &mut TxContext){
        //make sure time is valid, 7 days after started staking
        isValidTime(lstorage, clock);
        // make sure is the admin
        assert!(sender(ctx) == lstorage.admin, NOTADMIN);
        // make sure is during staking
        assert!(lstorage.isStaking == true, TIMENOTVALID);

        // do not update the totalvalue because it will be used to calculate the profits
        let option = 0;        // option?
        let profits = incentive_v2::claim_reward_with_account_cap(clock, incentive_v2, funds_pool, storage, SUIASSETID, option, &me.naviAccount);
        let pure_profits = balance::value(&profits);
        // pu the profits in the lstorage
        balance::join(&mut lstorage.profits, profits);
        let sui = incentive_v2::withdraw_with_account_cap(clock, oracle, storage, pool, SUIASSETID,lstorage.totalValue - 100000000, incentive_v1, incentive_v2, &me.naviAccount);
        let sui_value = balance::value(&sui);
        balance::join(&mut lstorage.profits, sui);

        // call the funtion choose winners before the customers can get their rewards
        chooseWiners(lstorage, candates, r, ctx);
        // update the staking symbol
        lstorage.isStaking == false;

        event::emit(WithdrawedFromNavi{
            timeStamp: clock::timestamp_ms(clock),
            SUI_value: sui_value,
            pure_profits
        });
    }

    // the function used to caculate the ratio of Sui each participiant put in the pool and choose the winers
    // only the admin can do this
    fun chooseWiners(lstorage:&LStorage, candates: &mut Candates, r: &Random, ctx: &mut TxContext){
        // get the random number and save in the vector
        let mut generator = new_generator(r, ctx);
        let mut randomNumbers = vector::empty<u64>();
        // caculate the totalshares of winners
        let mut totalWinnerShares = 0;

        let mut _i = 0;
        while (_i < candates.totalNumber / 20){ // the ratio is 5%
            let _number = random::generate_u64_in_range(&mut generator, 0, candates.totalNumber);
            // make sure not same 2 numbers
            if(!vector::contains(&randomNumbers, &_number)){
                totalWinnerShares = totalWinnerShares + table::borrow(&candates.candates, _number).shares;
                vector::push_back(&mut randomNumbers, _number);
            };
            _i = _i + 1;
        };
        let currentProfits = balance::value(&lstorage.profits) - lstorage.totalValue;
        let lenOfRandomNumbers = vector::length(&randomNumbers);

        let _j = 0;
        while (_j < lenOfRandomNumbers){
            let _winnerNumber = vector::remove(&mut randomNumbers, _j);
            let _winner = table::remove(&mut candates.candates, _winnerNumber);
            // add to the winner tables
            table::add(&mut candates.winers, _winner.address, (_winner.shares * currentProfits) / totalWinnerShares);
        };
        // destroy the randomvector
        vector::destroy_empty(randomNumbers);
    }

    // the function for customers to take the profits
    public entry fun takeProfits(clock: &Clock, lstorage: &mut LStorage, candates: &mut Candates, ctx: &mut TxContext){
        // make sure time is valid
        isValidTime(lstorage, clock);
        // make sure is not during staking
        assert!(lstorage.isStaking == false, DURINGSTAKING);
        // make sure is the winner
        if(table::contains(&candates.winers, sender(ctx))){
            // remove from the winners table
            let _amount = table::remove(&mut candates.winers, sender(ctx));
            let _sui = coin::take(&mut lstorage.profits, _amount, ctx);
            let valueTransfered = coin::value(&_sui);
            transfer::public_transfer(_sui, sender(ctx));
            event::emit(ProfitsTaken{winner: sender(ctx), rewards: valueTransfered});
        };
    }

    // A----3days------B-------7days--------C---3days---D---------7days------E......
    // only return true during the 3 days
    // this function will try to update the timestampA/B
    fun isValidTime(lstorage:&mut LStorage, clock: &Clock): bool{
        if(lstorage.timeB - lstorage.timeA == THREEDAYS){ //3
            if(clock::timestamp_ms(clock) >= lstorage.timeB){
                lstorage.timeA = lstorage.timeB;
                lstorage.timeB = lstorage.timeB +SEVENDAYS ;
                return false
            };
            return true
        }else { //7
            if(clock::timestamp_ms(clock) < lstorage.timeB){
                return false
            }else {
                lstorage.timeA = lstorage.timeB;
                lstorage.timeB = lstorage.timeB + THREEDAYS;
            };
            return true
        }
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext){
        init(DLOTTERY{}, ctx);
    }
    #[test_only]
    public fun test_create_pool(treasuryCap: &mut TreasuryCap<DLOTTERY>, clock: &Clock, ckey: &Candates, ctx: &mut TxContext){
        createPool(treasuryCap, clock, ckey, ctx);
    }
    #[test_only]
    public fun test_deposit(payment: coin::Coin<SUI>,  amount: u64, lstorage: &mut LStorage, candate: &mut Candates, clock: &Clock, ctx: &mut TxContext){
        deposit(payment, amount, lstorage, candate, clock, ctx);
    }
    #[test_only]
    public fun test_withdraw(amount: u64, shares: coin::Coin<DLOTTERY>, lstorage: &mut LStorage, candate: &mut Candates, clock: &Clock, ctx: &mut TxContext){
        withdraw(amount, shares, lstorage, candate, clock, ctx);
    }
    #[test_only]
    public fun test_takeProfits(clock: &Clock, lstorage: &mut LStorage, candates: &mut Candates, ctx: &mut TxContext){
        takeProfits(clock, lstorage, candates, ctx);
    }
}

