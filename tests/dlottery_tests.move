
#[test_only]
module dlottery::dlottery_tests {
    use sui::clock;
    use sui::coin;
    use sui::coin::{TreasuryCap, Coin};
    use sui::random;
    use sui::random::Random;
    use sui::sui::SUI;
    use sui::test_scenario;
    use sui::test_scenario::{ctx, next_tx, take_from_sender, take_shared, return_shared, return_to_sender};
    use dlottery::dlottery::{DLOTTERY, Candates, LStorage};
    use dlottery::dlottery;

    #[test]
    fun test_dlottery() {
        let admin = @0x0;
        let mut sce = test_scenario::begin(admin);//mut
        {
            dlottery::test_init(ctx(&mut sce));
        };
        next_tx(&mut sce, admin);
        { //create pool
            let mut _tcp = take_from_sender<TreasuryCap<DLOTTERY>>(&sce);
            let clock_test = clock::create_for_testing(ctx(&mut sce));
            dlottery::test_create_pool(&mut _tcp, &clock_test, ctx(&mut sce));
            test_scenario::return_to_sender(&sce, _tcp);
            clock::destroy_for_testing(clock_test);
        };
        next_tx(&mut sce, admin);
        { //deposit
            let _sui = coin::mint_for_testing<SUI>(20000000, ctx(&mut sce));
            let mut _candate = take_shared<Candates>(&sce);
            let mut _ls_storage = take_shared<LStorage>(&sce);
            let clock = clock::create_for_testing(ctx(&mut sce));
            dlottery::test_deposit(_sui, 2, &mut _ls_storage, &mut _candate, &clock, ctx(&mut sce));
            return_shared(_candate);
            return_shared(_ls_storage);
            clock::destroy_for_testing(clock);
        };
        next_tx(&mut sce, admin);
        { //withdraw
            let mut _candate = take_shared<Candates>(&sce);
            let mut _ls_storage = take_shared<LStorage>(&sce);
            let _clock = clock::create_for_testing(ctx(&mut sce));
            let _shares = take_from_sender<Coin<DLOTTERY>>(&sce);
            dlottery::test_withdraw(2, _shares, &mut _ls_storage, &mut _candate, &_clock, ctx(&mut sce));
            return_shared(_candate);
            return_shared(_ls_storage);
            clock::destroy_for_testing(_clock);
        };
        // set up random
        random::create_for_testing(ctx(&mut sce));
        next_tx(&mut sce, admin);
        { //choose winners
            let _r = take_shared<Random>(&sce);
            let mut _candate = take_shared<Candates>(&sce);
            let mut _ls_storage = take_shared<LStorage>(&sce);
            let _clock = clock::create_for_testing(ctx(&mut sce));
            dlottery::test_chooseWinners(&_clock, &mut _ls_storage, &mut _candate, &_r, ctx(&mut sce));
            return_shared(_candate);
            return_shared(_ls_storage);
            return_shared(_r);
            clock::destroy_for_testing(_clock);
        };
        next_tx(&mut sce, admin);
        {
            let mut _candate = take_shared<Candates>(&sce);
            let mut _ls_storage = take_shared<LStorage>(&sce);
            let _clock = clock::create_for_testing(ctx(&mut sce));
            dlottery::takeProfits(&_clock, &mut _ls_storage, &mut _candate, ctx(&mut sce));
            return_shared(_candate);
            return_shared(_ls_storage);
            clock::destroy_for_testing(_clock);
        };
        test_scenario::end(sce);
    }
}

