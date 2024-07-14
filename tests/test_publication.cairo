// *************************************************************************
//                              PUBLICATION TEST
// *************************************************************************
use core::option::OptionTrait;
use core::starknet::SyscallResultTrait;
use core::result::ResultTrait;
use core::traits::{TryInto, Into};
use starknet::{ContractAddress, class_hash::ClassHash, contract_address_const};
use snforge_std::{declare, ContractClassTrait, CheatTarget, start_prank, stop_prank};

use token_bound_accounts::interfaces::IAccount::{IAccountDispatcher, IAccountDispatcherTrait};
use token_bound_accounts::presets::account::Account;
use karst::mocks::registry::Registry;
use karst::interfaces::IRegistry::{IRegistryDispatcher, IRegistryDispatcherTrait};
use karst::karstnft::karstnft::KarstNFT;
use karst::mocks::interfaces::IComposable::{IComposableDispatcher, IComposableDispatcherTrait};
use karst::base::constants::types::{
    PostParams, MirrorParams, CommentParams, PublicationType, QuoteParams
};

const HUB_ADDRESS: felt252 = 'HUB';
const USER_ONE: felt252 = 'BOB';
const USER_TWO: felt252 = 'ALICE';
const USER_THREE: felt252 = 'ROB';

// *************************************************************************
//                              SETUP 
// *************************************************************************
fn __setup__() -> (
    ContractAddress,
    ContractAddress,
    ContractAddress,
    felt252,
    felt252,
    ContractAddress,
    ContractAddress,
    ContractAddress,
    u256,
) {
    // deploy NFT
    let nft_contract = declare("KarstNFT").unwrap();
    let names: ByteArray = "KarstNFT";
    let symbol: ByteArray = "KNFT";
    let base_uri: ByteArray = "";
    let mut calldata: Array<felt252> = array![USER_ONE];
    names.serialize(ref calldata);
    symbol.serialize(ref calldata);
    base_uri.serialize(ref calldata);
    let (nft_contract_address, _) = nft_contract.deploy(@calldata).unwrap_syscall();

    // deploy registry
    let registry_class_hash = declare("Registry").unwrap();
    let (registry_contract_address, _) = registry_class_hash.deploy(@array![]).unwrap_syscall();

    // deploy publication
    let publication_contract = declare("KarstPublication").unwrap();
    let mut publication_constructor_calldata = array![HUB_ADDRESS];
    let (publication_contract_address, _) = publication_contract
        .deploy(@publication_constructor_calldata)
        .unwrap_syscall();

    // declare account
    let account_class_hash = declare("Account").unwrap();

    // deploying karst Profile for USER 1
    let dispatcher = IComposableDispatcher {
        contract_address: publication_contract_address
    };
    start_prank(CheatTarget::One(publication_contract_address), USER_ONE.try_into().unwrap());
    let user_one_profile_address = dispatcher
        .create_profile(
            nft_contract_address,
            registry_class_hash.class_hash.into(),
            account_class_hash.class_hash.into(),
            2478
        );
    let content_URI: ByteArray = "ipfs://helloworld";
    let user_one_first_post_pointed_pub_id = dispatcher.post(
        PostParams {
            content_URI: content_URI,
            profile_address: user_one_profile_address
        }
    );
    stop_prank(CheatTarget::One(publication_contract_address),);

    // deploying karst Profile for USER 2
    start_prank(CheatTarget::One(publication_contract_address), USER_TWO.try_into().unwrap());
    let user_two_profile_address = dispatcher
        .create_profile(
            nft_contract_address,
            registry_class_hash.class_hash.into(),
            account_class_hash.class_hash.into(),
            2479
        );
    let content_URI: ByteArray = "ipfs://helloworld";
    dispatcher.post(
        PostParams {
            content_URI: content_URI,
            profile_address: user_two_profile_address
        }
    );
    stop_prank(CheatTarget::One(publication_contract_address),);

    // deploying karst Profile for USER 3
    start_prank(CheatTarget::One(publication_contract_address), USER_THREE.try_into().unwrap());
    let user_three_profile_address = dispatcher
        .create_profile(
            nft_contract_address,
            registry_class_hash.class_hash.into(),
            account_class_hash.class_hash.into(),
            2480
        );
    let content_URI: ByteArray = "ipfs://helloworld";
    dispatcher.post(
        PostParams {
            content_URI: content_URI,
            profile_address: user_three_profile_address
        }
    );
    stop_prank(CheatTarget::One(publication_contract_address));

    return (
        nft_contract_address,
        registry_contract_address,
        publication_contract_address,
        registry_class_hash.class_hash.into(),
        account_class_hash.class_hash.into(),
        user_one_profile_address,
        user_two_profile_address,
        user_three_profile_address,
        user_one_first_post_pointed_pub_id,
    );
}

// *************************************************************************
//                              TEST
// *************************************************************************

#[test]
fn test_post() {
    let (
        _,
        _,
        publication_contract_address,
        _,
        _,
        user_one_profile_address,
        _,
        _,
        user_one_first_post_pointed_pub_id,
    ) =__setup__();

    let dispatcher = IComposableDispatcher {
        contract_address: publication_contract_address
    };

    start_prank(CheatTarget::One(publication_contract_address), USER_ONE.try_into().unwrap());
    let publication_type = dispatcher
        .get_publication_type(user_one_profile_address, user_one_first_post_pointed_pub_id);
    assert(publication_type == PublicationType::Post, 'invalid pub_type');
    assert(user_one_first_post_pointed_pub_id == 1_u256, 'invalid pub id');
    stop_prank(CheatTarget::One(publication_contract_address));
}

#[test]
fn test_comment() {
    let (
        _,
        _,
        publication_contract_address,
        _,
        _,
        user_one_profile_address,
        user_two_profile_address,
        _,
        user_one_first_post_pointed_pub_id,
    ) =__setup__();

    let dispatcher = IComposableDispatcher {
        contract_address: publication_contract_address
    };

    start_prank(CheatTarget::One(publication_contract_address), USER_ONE.try_into().unwrap());
    let content_URI_1 =
        "ipfs://QmSkDCsS32eLpcymxtn1cEn7Rc5hfefLBgfvZyjaryrga/";
    let content_URI_2 =
        "ipfs://QmSkDCsS32eLpcymxtn1cEn7Rc5hfefLBgfvZysddewga/";

    // user comment on his own post
    let user_one_comment_assigned_pub_id_1 = dispatcher
        .comment(
            CommentParams {
                profile_address: user_one_profile_address,
                content_URI: content_URI_1,
                pointed_profile_address: user_one_profile_address,
                pointed_pub_id: user_one_first_post_pointed_pub_id,
                reference_pub_type: PublicationType::Comment
            }
        );
    // user two comment on user_one_post
    let user_two_comment_on_user_one_assigned_pub_id_2 = dispatcher
        .comment(
            CommentParams {
                profile_address: user_two_profile_address,
                content_URI: content_URI_2,
                pointed_profile_address: user_one_profile_address,
                pointed_pub_id: user_one_first_post_pointed_pub_id,
                reference_pub_type: PublicationType::Comment
            }
        );

    let user_one_comment = dispatcher
        .get_publication(user_one_profile_address, user_one_comment_assigned_pub_id_1);
    let user_two_comment = dispatcher
        .get_publication(user_two_profile_address, user_two_comment_on_user_one_assigned_pub_id_2);
    let publication_type_1 = dispatcher
        .get_publication_type(user_one_profile_address, user_one_comment_assigned_pub_id_1);
    let publication_type_2 = dispatcher
        .get_publication_type(user_two_profile_address, user_two_comment_on_user_one_assigned_pub_id_2);

    assert(publication_type_1 == PublicationType::Comment, 'invalid pub_type');
    assert(publication_type_2 == PublicationType::Comment, 'invalid pub_type');
    // assert(user_one_publication_root_id == user_two_comment_publication_root_id, 'Invalid root_id');

    stop_prank(CheatTarget::One(publication_contract_address),);
}

// #[test]
// #[should_panic(expected: ('Karst: unsupported pub type!',))]
// fn test_with_as_reference_pub_params() {
//     let (
//         _,
//         _,
//         publication_contract_address,
//         _,
//         _,
//         user_one_profile_address,
//         _,
//         _,
//         user_one_first_post_pointed_pub_id,
//     ) =
//         __setup__();
//     let publication_dispatcher = IComposableDispatcher {
//         contract_address: publication_contract_address
//     };
//     start_prank(CheatTarget::One(publication_contract_address), USER_ONE.try_into().unwrap());

//     let user_one_comment_on_his_post_content_URI =
//         "ipfs://QmSkDCsS32eLpcymxtn1cEn7Rc5hfefLBgfvZyjaryrga/";

//     // user comment on his own post
//     publication_dispatcher
//         .comment(
//             user_one_profile_address,
//             PublicationType::Mirror,
//             user_one_comment_on_his_post_content_URI,
//             user_one_profile_address,
//             user_one_first_post_pointed_pub_id,
//             publication_contract_address
//         );

//     stop_prank(CheatTarget::One(publication_contract_address),);
// }

// #[test]
// fn test_quote() {
//     let (
//         _,
//         _,
//         publication_contract_address,
//         _,
//         _,
//         user_one_profile_address,
//         user_two_profile_address,
//         user_three_profile_address,
//         user_one_first_post_pointed_pub_id,
//     ) =
//         __setup__();
//     let publication_dispatcher = IComposableDispatcher {
//         contract_address: publication_contract_address
//     };
//     start_prank(CheatTarget::One(publication_contract_address), USER_ONE.try_into().unwrap());
//     let quote_content_URI = "ipfs://QmSkDCsS32eLpcymxtn1cEn7Rc5hfefLBgfvZysddefzp/";

//     let quote_params = QuoteParams {
//         profile_address: user_two_profile_address,
//         content_URI: quote_content_URI,
//         pointed_profile_address: user_one_profile_address,
//         pointed_pub_id: user_one_first_post_pointed_pub_id
//     };
//     // user one publish quote to user 2 profile
//     let quote_pub_id = publication_dispatcher
//         .quote(PublicationType::Quote, quote_params, publication_contract_address);

//     let publication_type = publication_dispatcher
//         .get_publication_type(user_two_profile_address, quote_pub_id);
//     assert(publication_type == PublicationType::Quote, 'invalid pub_type');

//     stop_prank(CheatTarget::Multiple(array![publication_contract_address]),);

//     start_prank(CheatTarget::One(publication_contract_address), USER_TWO.try_into().unwrap());
//     let user_two_quote_content_URI = "ipfs://QmSkDCsS32eLpcymxtn1cEn7Rc5hfefLBgfvZysdjbezo/";

//     let user_two_quote_params = QuoteParams {
//         profile_address: user_three_profile_address,
//         content_URI: user_two_quote_content_URI,
//         pointed_profile_address: user_one_profile_address,
//         pointed_pub_id: user_one_first_post_pointed_pub_id
//     };
//     // user 2 publish quote to user 3 profile
//     let user_two_quote_pub_id = publication_dispatcher
//         .quote(PublicationType::Quote, user_two_quote_params, publication_contract_address);

//     let publication_type = publication_dispatcher
//         .get_publication_type(user_three_profile_address, user_two_quote_pub_id);
//     assert(publication_type == PublicationType::Quote, 'invalid pub_type');

//     let user_one_publication_root_id = publication_dispatcher
//         .get_publication(user_two_profile_address, quote_pub_id)
//         .root_profile_address;
//     let user_two_publication_root_id = publication_dispatcher
//         .get_publication(user_three_profile_address, user_two_quote_pub_id)
//         .root_profile_address;
//     assert(user_one_publication_root_id == user_two_publication_root_id, 'Invalid root_id');

//     stop_prank(CheatTarget::One(publication_contract_address));
// }

// #[test]
// #[should_panic(expected: ('Karst: unsupported pub type!',))]
// fn test_quote_as_reference_pub_params() {
//     let (
//         _,
//         _,
//         publication_contract_address,
//         _,
//         _,
//         user_one_profile_address,
//         user_two_profile_address,
//         _,
//         user_one_first_post_pointed_pub_id,
//     ) =
//         __setup__();
//     let publication_dispatcher = IComposableDispatcher {
//         contract_address: publication_contract_address
//     };

//     start_prank(CheatTarget::One(publication_contract_address), USER_ONE.try_into().unwrap());

//     let quote_content_URI = "ipfs://QmSkDCsS32eLpcymxtn1cEn7Rc5hfefLBgfvZysddefzp/";

//     let quote_params = QuoteParams {
//         profile_address: user_two_profile_address,
//         content_URI: quote_content_URI,
//         pointed_profile_address: user_one_profile_address,
//         pointed_pub_id: user_one_first_post_pointed_pub_id
//     };

//     publication_dispatcher
//         .quote(PublicationType::Mirror, quote_params, publication_contract_address);

//     stop_prank(CheatTarget::One(publication_contract_address),);
// }

// #[test]
// fn test_quote_pointed_profile_address() {
//     let (
//         _,
//         _,
//         publication_contract_address,
//         _,
//         _,
//         user_one_profile_address,
//         user_two_profile_address,
//         _,
//         user_one_first_post_pointed_pub_id,
//     ) =
//         __setup__();
//     let publication_dispatcher = IComposableDispatcher {
//         contract_address: publication_contract_address
//     };
//     start_prank(CheatTarget::One(publication_contract_address), USER_ONE.try_into().unwrap());
//     let quote_content_URI = "ipfs://QmSkDCsS32eLpcymxtn1cEn7Rc5hfefLBgfvZysddefzp/";

//     let quote_params = QuoteParams {
//         profile_address: user_two_profile_address,
//         content_URI: quote_content_URI,
//         pointed_profile_address: user_one_profile_address,
//         pointed_pub_id: user_one_first_post_pointed_pub_id
//     };

//     start_prank(CheatTarget::One(publication_contract_address), USER_ONE.try_into().unwrap());
//     let publicationDispatcher = IComposableDispatcher {
//         contract_address: publication_contract_address
//     };

//     publication_dispatcher
//         .quote(PublicationType::Quote, quote_params, publication_contract_address);

//     let pointed_profile = publicationDispatcher.get_profile(user_one_profile_address);

//     assert(
//         pointed_profile.profile_address == user_one_profile_address,
//         'Invalid Pointed Profile Address'
//     );

//     stop_prank(CheatTarget::One(publication_contract_address),);
// }

// #[test]
// fn test_publish_mirror() {
//     let (
//         _,
//         _,
//         publication_contract_address,
//         _,
//         _,
//         user_one_profile_address,
//         user_two_profile_address,
//         _,
//         user_one_first_post_pointed_pub_id,
//     ) =
//         __setup__();
//     let publication_dispatcher = IComposableDispatcher {
//         contract_address: publication_contract_address
//     };

//     let metadata_URI = "ipfs://QmSkDCsS32eLpcymxtn1cEn7Rc5hfefLBgfvZysddewga/";

//     let mirror_params = MirrorParams {
//         profile_address: user_one_profile_address,
//         metadata_URI: metadata_URI,
//         pointed_profile_address: user_two_profile_address,
//         pointed_pub_id: user_one_first_post_pointed_pub_id,
//     };

//     start_prank(CheatTarget::One(publication_contract_address), USER_ONE.try_into().unwrap());
//     let publicationDispatcher = IComposableDispatcher {
//         contract_address: publication_contract_address
//     };

//     let pub_id_assigned = publicationDispatcher
//         .get_user_publication_count(user_one_profile_address);
//     let pub_assign_id = publication_dispatcher.mirror(mirror_params, publication_contract_address);

//     assert(pub_id_assigned == pub_assign_id, 'Invalid publication id assign');

//     stop_prank(CheatTarget::One(publication_contract_address),);
// }

// #[test]
// fn test_two_publish_mirror() {
//     let (
//         _,
//         _,
//         publication_contract_address,
//         _,
//         _,
//         user_one_profile_address,
//         user_two_profile_address,
//         user_three_profile_address,
//         user_one_first_post_pointed_pub_id,
//     ) =
//         __setup__();

//     let publication_dispatcher = IComposableDispatcher {
//         contract_address: publication_contract_address
//     };

//     let metadata_URI = "ipfs://QmSkDCsS32eLpcymxtn1cEn7Rc5hfefLBgfvZysddewga/";

//     let metadata_URI_1 = "ipfs://QmSkDCsS32eLpcymxtn1cEn7Rc5hfefLBgfvZysddewga/";

//     start_prank(CheatTarget::One(publication_contract_address), USER_TWO.try_into().unwrap());
//     let mirror_params = MirrorParams {
//         profile_address: user_one_profile_address,
//         metadata_URI: metadata_URI,
//         pointed_profile_address: user_two_profile_address,
//         pointed_pub_id: user_one_first_post_pointed_pub_id,
//     };

//     publication_dispatcher.mirror(mirror_params, publication_contract_address);

//     stop_prank(CheatTarget::One(publication_contract_address),);

//     start_prank(CheatTarget::One(publication_contract_address), USER_THREE.try_into().unwrap());

//     let mirror_params_1 = MirrorParams {
//         profile_address: user_one_profile_address,
//         metadata_URI: metadata_URI_1,
//         pointed_profile_address: user_three_profile_address,
//         pointed_pub_id: user_one_first_post_pointed_pub_id,
//     };

//     publication_dispatcher.mirror(mirror_params_1, publication_contract_address);

//     let pointed_profile_three = publication_dispatcher.get_profile(user_three_profile_address);

//     assert(
//         pointed_profile_three.profile_address == user_three_profile_address,
//         'Invalid publication id assign'
//     );

//     stop_prank(CheatTarget::One(publication_contract_address),);
// }

// #[test]
// fn test_mirror_pointed_profile_address() {
//     let (
//         _,
//         _,
//         publication_contract_address,
//         _,
//         _,
//         user_one_profile_address,
//         user_two_profile_address,
//         _,
//         user_one_first_post_pointed_pub_id,
//     ) =
//         __setup__();
//     let publication_dispatcher = IComposableDispatcher {
//         contract_address: publication_contract_address
//     };

//     let metadata_URI = "ipfs://QmSkDCsS32eLpcymxtn1cEn7Rc5hfefLBgfvZysddewga/";

//     let mirror_params = MirrorParams {
//         profile_address: user_one_profile_address,
//         metadata_URI: metadata_URI,
//         pointed_profile_address: user_two_profile_address,
//         pointed_pub_id: user_one_first_post_pointed_pub_id,
//     };

//     start_prank(CheatTarget::One(publication_contract_address), USER_ONE.try_into().unwrap());

//     publication_dispatcher.mirror(mirror_params, publication_contract_address);

//     let pointed_profile = publication_dispatcher.get_profile(user_one_profile_address);

//     assert(
//         pointed_profile.profile_address == user_one_profile_address,
//         'Invalid Pointed Profile Address'
//     );

//     stop_prank(CheatTarget::One(publication_contract_address),);
// }

// #[test]
// fn test_mirror_root_profile_address() {
//     let (
//         _,
//         _,
//         publication_contract_address,
//         _,
//         _,
//         user_one_profile_address,
//         user_two_profile_address,
//         _,
//         user_one_first_post_pointed_pub_id,
//     ) =
//         __setup__();
//     let publication_dispatcher = IComposableDispatcher {
//         contract_address: publication_contract_address
//     };

//     let metadata_URI = "ipfs://QmSkDCsS32eLpcymxtn1cEn7Rc5hfefLBgfvZysddewga/";

//     let mirror_params = MirrorParams {
//         profile_address: user_one_profile_address,
//         metadata_URI: metadata_URI,
//         pointed_profile_address: user_two_profile_address,
//         pointed_pub_id: user_one_first_post_pointed_pub_id,
//     };

//     start_prank(CheatTarget::One(publication_contract_address), USER_ONE.try_into().unwrap());

//     publication_dispatcher.mirror(mirror_params, publication_contract_address);

//     let pointed_profile = publication_dispatcher.get_profile(user_two_profile_address);

//     assert(
//         pointed_profile.profile_address == user_two_profile_address, 'Invalid Root Profile Address'
//     );

//     stop_prank(CheatTarget::One(publication_contract_address),);
// }
