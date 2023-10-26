/* 
    This quest features the move module for a decentralized social media platform. The platform 
    allows users to create and manage accounts, follow other accounts, and post, comment, and like 
    content. Account ownership is handled through NFTs. 

    NOTE: Remember to visit https://overmind.xyz/quests/over-network and click `Submit Quest` for your
    submission to be reviewed and accepted!

    Account NFT collection
        Every account in the platform is represented by the ownership of an account NFT. The 
        account collection is an unlimited collection that holds each NFT. The collection's name is 
        "account collection", the description is "account collection description", and the URI is
        "account collection uri". The collection has no royalty fee and the supply is trackable.

    Account NFT and data
        Each NFT represents an account in the platform. The name of the NFT is the username of the 
        account. The description and URI are both empty strings (b""). The NFT has no royalty fee. 

        Each NFT holds two resources: AccountMetaData and Publications. AccountMetaData holds the 
        metadata for the account and Publications holds all of the posts, comments, and likes that 
        the account has made.

        The data in the AccountMetaData resource is limited as follows: 
            - The username must be between 1 and 32 characters long (inclusive).
            - The name must be no longer than 60 characters long.
            - The profile picture URI must be no longer than 256 characters long.
            - The bio must be no longer than 160 characters long.

        The data in the Publications resource is limited as follows:
            - The content of a post must be no longer than 280 characters long.
            - The content of a comment must be no longer than 280 characters long.

    Account registry
        The AccountRegistry struct holds a mapping of registered usernames to the address of the
        associated account NFT. The account registry is stored in the module's State resource.

        Anyone is able to create a new account as long as the username is not already registered. 

    Publications
        In this platform, the three types of publications are posts, comments, and likes. 

        Posts
            Posts are the main type of publication in the platform. Posts are created by accounts
            and can be commented on and liked. Posts are stored in the account's Publications
            resource.

            Posts cannot be edited or deleted once they are created.
        
        Comments
            Comments are publications that are made on posts. Comments are created by accounts and
            can be liked. Comments are stored in the account's Publications resource.

            Comments cannot be edited or deleted once they are created.

        Likes
            Likes are publications that are made on posts and comments. Likes are created by 
            accounts. Likes are stored in the account's Publications resource.

            Accounts are able to like a post or comment only once. Accounts are able to unlike a
            post or comment only if they have already liked it.
            
    References 
        All original publication data are stored in each account's Publications resource. In order 
        to avoid storing duplicate data, references to the original publications are stored in 
        other accounts' Publications. 

        For example, if account A posts a post, then the post is stored in account A's Publications
        resource. If account B comments on the post, then the comment is stored in account B's
        Publications resource. In addition, a reference to the comment is stored in account A's
        post in account A's Publications resource and a reference to the post is stored in account
        B's comment in account B's Publications resource.

        The PublicationReference struct holds the data needed to reference a publication. This 
        contains the address of the account that owns the publication, the type of the publication,
        and the index of the publication in the account's associated Publications resource list.

    GlobalTimeline
        The GlobalTimeline resource holds references to each post created in the platform. The 
        GlobalTimeline resource is stored in the module's resource account.

    Following
        Accounts are able to follow/unfollow other accounts. When an account follows another 
        account, the metadata of each account is updated to reflect the new follow.

    View functions
        This platform has a collection of view functions which are used to query the state of the 
        platform without modifying the it. 

        Pagination
            The view function include pagination parameters so that the caller can specify how much
            data they want to receive. The pagination parameters are:
                - page_size: The number of items to return in the page
                - page: The page number to return (0-indexed)

        Aborting in view functions
            View functions are designed to not abort but rather return empty data if given invalid 
            parameters. 

            The empty values for each type are: 
                - String - string::utf8(b"")
                - vectors - vector[]
                - u64 - 0
                - address - @0x0
                - boolean - false

    Error codes
        The module provides the following error codes to use: 
            - EUsernameAlreadyRegistered
                This error code is to be used when an account tries to create an account with a
                username that is already registered.
            - EUsernameNotRegistered
                This error code is to be used when an account tries to perform an action with or 
                on an account that is not registered.
            - EAccountDoesNotOwnUsername
                This error code is to be used when an account tries to perform an action with an 
                username that is not owned by them.
            - EBioInvalidLength
                This error code is to be used when an account tries to create or update an account
                with a bio that is not valid length.
            - EUserDoesNotFollowUser
                This error code is to be used when an account tries to unfollow an account that 
                they do not follow.
            - EUserFollowsUser
                This error code is to be used when an account tries to follow an account that they
                already follow.
            - EPublicationDoesNotExistForUser
                This error code is to be used when an account tries to perform an action on a 
                publication that does not exist.
            - EPublicationTypeToLikeIsInvalid
                This error code is to be used when an account tries to like a publication with an
                invalid type.
            - EUserHasLikedPublication
                This error code is to be used when an account tries to like a publication that they
                have already liked.
            - EUserHasNotLikedPublication
                This error code is to be used when an account tries to unlike a publication that 
                they have not liked.
            - EUsersAreTheSame
                This error code is to be used when an account tries to follow or unfollow itself.
            - EInvalidPublicationType
                This error code is to be used when an account tries to perform an action on a 
                publication with an invalid type.
            - EUsernameInvalidLength
                This error code is to be used when an account tries to create or update an account 
                with a username that is not valid length.
            - ENameInvalidLength
                This error code is to be used when an account tries to create or update an account 
                with a name that is not valid length.
            - EProfilePictureUriInvalidLength
                This error code is to be used when an account tries to create or update an account 
                with a profile picture URI that is not valid length.
            - EContentInvalidLength
                This error code is to be used when an account tries to create a post or comment 
                with content that is not valid length.
*/
module overmind::over_network {
    //==============================================================================================
    // Dependencies
    //==============================================================================================
    use std::signer;
    use std::option::{Self};
    use aptos_framework::event;
    use aptos_framework::object;
    use aptos_framework::vector;
    use aptos_framework::account;
    use std::table::{Self, Table};
    use aptos_framework::timestamp;
    use aptos_token_objects::token;
    use std::string::{Self, String};
    use aptos_token_objects::collection;


    //==============================================================================================
    // Constants - DO NOT MODIFY
    //==============================================================================================
    const SEED: vector<u8> = b"decentralized platform";
    
    //==============================================================================================
    // Error codes - DO NOT MODIFY
    //==============================================================================================
    const EUsernameAlreadyRegistered: u64 = 1;
    const EUsernameNotRegistered: u64 = 2;
    const EAccountDoesNotOwnUsername: u64 = 3;
    const EBioInvalidLength: u64 = 4;
    const EUserDoesNotFollowUser: u64 = 5;
    const EUserFollowsUser: u64 = 6;
    const EPublicationDoesNotExistForUser: u64 = 7;
    const EPublicationTypeToLikeIsInvalid: u64 = 8;
    const EUserHasLikedPublication: u64 = 9;
    const EUserHasNotLikedPublication: u64 = 10;
    const EUsersAreTheSame: u64 = 11;
    const EInvalidPublicationType: u64 = 12;
    const EUsernameInvalidLength: u64 = 13;
    const ENameInvalidLength: u64 = 14;
    const EProfilePictureUriInvalidLength: u64 = 15;
    const EContentInvalidLength: u64 = 16;


    //==============================================================================================
    // Module Structs - DO NOT MODIFY
    //==============================================================================================

    /*
        The resource that holds all of the publication for an account. To be owned by the account 
        NFT.
    */
    struct Publications has key {
        // List of account's posts
        posts: vector<Post>, 
        // List of account's comments
        comments: vector<Comment>, 
        // List of account's likes
        likes: vector<Like>
    }

    /*
        The data struct for an account's post. To be stored in the account's Publications resource.
    */
    struct Post has store, copy, drop {
        // Timestamp of when the post was created
        timestamp: u64,
        // The id of the post
        id: u64,
        // The content of the post
        content: String, 
        // The references to the comments on the post
        comments: vector<PublicationReference>, 
        // The usernames of the accounts that like the post
        likes: vector<String>
    }

    /*
        The data struct for an account's comment. To be stored in the account's Publications 
        resource.
    */
    struct Comment has store, copy, drop {
        // Timestamp of when the comment was created
        timestamp: u64,
        // The id of the comment
        id: u64,
        // The content of the comment
        content: String, 
        // The reference to the post the comment is on
        reference: PublicationReference,
        // The usernames of the accounts that like the comment
        likes: vector<String>,
    }

    /*
        The data struct for an account's like. To be stored in the account's Publications resource.
    */
    struct Like has store, copy, drop {
        // Timestamp of when the like was created
        timestamp: u64,
        // The reference to the publication that was liked
        reference: PublicationReference
    }

    /*
        The data struct for a reference to a publication. To be stored in the account's Publications
        resource.
    */
    struct PublicationReference has store, copy, drop {
        // The address of the account that owns the publication
        publication_author_account_address: address, 
        // The type of the publication
        publication_type: String, 
        // The index of the publication in the account's Publications resource
        publication_index: u64
    }

    /*
        The resource that holds all of an account's metadata. To be owned by the account NFT.
    */
    struct AccountMetaData has key, copy, drop {
        // The timestamp of when the account was created
        creation_timestamp: u64,
        // The address of the account NFT
        account_address: address,
        // The username of the account
        username: String,
        // The name of the account owner
        name: String,
        // The URI of the profile picture of the account
        profile_picture_uri: String,
        // The bio of the account
        bio: String,
        // The usernames of the accounts that follow the account
        follower_account_usernames: vector<String>,
        // The usernames of the accounts that the account follows
        following_account_usernames: vector<String>
    }

    /*
        The data struct that holds all of the accounts registered in the platform. To be stored in
        the module's State resource.
    */
    struct AccountRegistry has store {
        // The mapping of usernames to account addresses
        accounts: Table<String, address>
    }

    /*
        The resource that holds the state of the module. To be owned by the module's resource 
        account.
    */
    struct State has key {
        // The address of the account NFT collection
        account_collection_address: address,
        // The account registry
        account_registry: AccountRegistry, 
        // The signer capability for the module's resource account
        signer_cap: account::SignerCapability
    }

    /*
        The resource that holds all of the module's event handles. To be owned by the module's 
        resource account.
    */
    struct ModuleEventStore has key {
        // The event handle for account created events
        account_created_events: event::EventHandle<AccountCreatedEvent>,
        // The event handle for account follow events
        account_follow_events: event::EventHandle<AccountFollowEvent>,
        // The event handle for account unfollow events
        account_unfollow_events: event::EventHandle<AccountUnfollowEvent>,
        // The event handle for account post events
        account_post_events: event::EventHandle<AccountPostEvent>,
        // The event handle for account comment events
        account_comment_events: event::EventHandle<AccountCommentEvent>,
        // The event handle for account like events
        account_like_events: event::EventHandle<AccountLikeEvent>,
        // The event handle for account unlike events
        account_unlike_events: event::EventHandle<AccountUnlikeEvent>,
    }

    /*
        The resource that holds references for each post in the platform. To be owned by the
        module's resource account.
    */
    struct GlobalTimeline has key {
        // The list of references to each post in the platform
        posts: vector<PublicationReference>
    }
    
    //==============================================================================================
    // Event structs - DO NOT MODIFY
    //==============================================================================================
    /*
        Event to be emitted when an account is created. 
    */
    struct AccountCreatedEvent has store, drop {
        // The timestamp of when the account was created
        timestamp: u64,
        // The address of the account NFT
        account_address: address, 
        // The username of the account
        username: String, 
        // The address of the account that created the account
        creator: address
    }

    /*
        Event to be emitted when an account follows another account.
    */
    struct AccountFollowEvent has store, drop {
        // The timestamp of when the account followed another account
        timestamp: u64,
        // The username of the account that followed another account
        follower_account_username: String,
        // The username of the account that was followed
        following_account_username: String
    }

    /*
        Event to be emitted when an account unfollows another account.
    */
    struct AccountUnfollowEvent has store, drop {
        // The timestamp of when the account unfollowed another account
        timestamp: u64,
        // The username of the account that unfollowed another account
        unfollower_account_username: String,
        // The username of the account that was unfollowed
        unfollowing_account_username: String
    }

    /*
        Event to be emitted when an account posts a new post.
    */
    struct AccountPostEvent has store, drop {
        // The timestamp of when the account posted a new post
        timestamp: u64,
        // The username of the account that posted a new post
        poster_username: String,
        // The id of the post
        post_id: u64,
    }

    /*
        Event to be emitted when an account comments on a post.
    */
    struct AccountCommentEvent has store, drop {
        // The timestamp of when the account commented on a post
        timestamp: u64,
        // The username of the account that owns the post
        post_owner_username: String,
        // The id of the post
        post_id: u64,
        // The username of the account that commented on the post
        commenter_username: String,
        // The id of the comment
        comment_id: u64,
    }

    /*
        Event to be emitted when an account likes a publication.
    */
    struct AccountLikeEvent has store, drop {
        // The timestamp of when the account liked a publication
        timestamp: u64,
        // The username of the account owns the publication
        publication_owner_username: String,
        // The type of the publication that was liked
        publication_type: String,
        // The id of the publication that was liked
        publication_id: u64,
        // The username of the account that liked the publication
        liker_username: String
    }

    /*
        Event to be emitted when an account unlikes a publication.
    */
    struct AccountUnlikeEvent has store, drop {
        // The timestamp of when the account unliked a publication
        timestamp: u64,
        // The username of the account owns the publication
        publication_owner_username: String,
        // The type of the publication that was unliked
        publication_type: String,
        // The id of the publication that was unliked
        publication_id: u64,
        // The username of the account that unliked the publication
        unliker_username: String
    }

    //==============================================================================================
    // Functions
    //==============================================================================================

    /* 
        Initializes the module by creating the resource account, creating the account NFT collection,
        and creating and moving the State, ModuleEventStore, and GlobalTimeline resources to the
        resource account.
        @param admin - The signer representing the publisher of the module
    */
    fun init_module(admin: &signer) {

    }

    /* 
        Creates and sets up a new account with the associated data for the owner account. Updates 
        module state as needed. Aborts if the username, name, or profile pic uri is not valid 
        length, the username is already registered, if any of the usernames to follow are not 
        registered, if there is a repeated username in the list, or if the list contains the 
        username of the account being created.
        @param owner - The signer representing the account registering the new account
        @param username - The username of the new account
        @param name - The name of the new account owner
        @param profile_pic - The URI of the profile picture of the new account 
        @param usernames_to_follow - A list of usernames to follow after creating the account. Can 
            be empty.
    */
    entry fun create_account(
        owner: &signer, 
        username: String,
        name: String, 
        profile_pic: String,
        usernames_to_follow: vector<String>
    ) acquires State, ModuleEventStore, AccountMetaData {

    }

    /*
        Updates the name of the account associated with the given username. Aborts if the name is 
        not valid length, if the username is not registered, or if the account associated with the 
        username is not owned by the owner account.
        @param owner - The signer representing the owner of the account to update
        @param username - The username of the account to update
        @param name - The new name of the account
    */
    entry fun update_name(
        owner: &signer,
        username: String,
        name: String
    ) acquires State, AccountMetaData {

    }

    /*
        Updates the bio of the account associated with the given username. Aborts if the bio is too
        long, if the username is not registered, or if the account associated with the username is
        not owned by the owner account.
        @param owner - The signer representing the owner of the account to update
        @param username - The username of the account to update
        @param bio - The new bio of the account
    */
    entry fun update_bio(
        owner: &signer, 
        username: String, 
        bio: String
    ) acquires State, AccountMetaData {

    }

    /*
        Updates the profile picture of the account associated with the given username. Aborts if
        the new profile pic uri is not valid length, the username is not registered or if the 
        account associated with the username is not owned by the owner account.
        @param owner - The signer representing the owner of the account to update
        @param username - The username of the account to update
        @param profile_picture_uri - The new profile picture URI of the account
    */
    entry fun update_profile_picture(
        owner: &signer,
        username: String, 
        profile_picture_uri: String
    ) acquires State, AccountMetaData {

    }

    /*
        Follows the account associated with the given username. Aborts if either username is not
        registered, if the account associated with the follower username is not owned by the owner
        account, if the username to follow is the same as the follower username or if the account 
        associated with the follower username already follows the account to follow. 
        @param follower - The signer representing the owner of the account to follow with
        @param follower_username - The username of the account to follow with
        @param username_to_follow - The username of the account to follow
    */
    entry fun follow(
        follower: &signer,
        follower_username: String,
        username_to_follow: String
    ) acquires State, ModuleEventStore, AccountMetaData {

    }

    /*
        Unfollows the account associated with the given username. Aborts if either username is not
        registered, if the account associated with the unfollower username is not owned by the 
        owner account, if the username to unfollow is the same as the unfollower username or if the 
        account associated with the unfollower username does not follow the account to unfollow. 
        @param unfollower - The signer representing the owner of the account to unfollow with
        @param unfollower_username - The username of the account to unfollow with
        @param username_to_unfollow - The username of the account to unfollow
    */
    entry fun unfollow(
        unfollower: &signer,
        unfollower_username: String,
        username_to_unfollow: String
    ) acquires State, ModuleEventStore, AccountMetaData {

    }

    /*
        Posts a new post with the given content to the account associated with the given username.
        Aborts if the username is not registered, if the account associated with the username is
        not owned by the owner account, or if the content is not valid length.
        @param owner - The signer representing the owner of the account to post with
        @param username - The username of the account to post with
        @param content - The content of the post
    */
    entry fun post(
        owner: &signer, 
        username: String, 
        content: String, 
    ) acquires State, ModuleEventStore, Publications, GlobalTimeline {

    }

    /*  
        Comments on the post associated with the given username and id with the given content. 
        Aborts if the content is not valid length, if the commenter username is not registered, if 
        the post author username is not registered, if the account associated with the 
        commenter username is not owned by the owner account, or if the post does not exist.
        @param commenter - The signer representing the owner of the account to comment with
        @param commenter_username - The username of the account to comment with
        @param content - The content of the comment
        @param post_author_username - The username of the account that owns the post to comment on
        @param post_id - The id of the post to comment on
    */
    entry fun comment(
        commenter: &signer,
        commenter_username: String, 
        content: String,
        post_author_username: String,
        post_id: u64,
    ) acquires State, ModuleEventStore, Publications {

    }

    /*
        Likes the publication associated with the given username, type, and id. Aborts if the 
        publication type is invalid, if the liker username is not registered, if the publication 
        author username is not registered, if the account associated with the liker username is not
        owned by the owner account, if the username has already liked the publication or if the 
        publication does not exist.
        @param liker - The signer representing the owner of the account to like with
        @param liker_username - The username of the account to like with
        @param publication_author_username - The username of the account that owns the publication
        @param publication_type - The type of the publication to like
        @param publication_id - The id of the publication to like
    */
    entry fun like(
        liker: &signer,
        liker_username: String,
        publication_author_username: String,
        publication_type: String,
        publication_id: u64,
    ) acquires State, ModuleEventStore, Publications {

    }

    /*
        Unlikes the publication associated with the given username, type, and id. Aborts if the 
        publication type is invalid, if the unliker username is not registered, if the publication 
        author username is not registered, if the account associated with the unliker username is 
        not owned by the owner account, if the username has not liked the publication or if the 
        publication does not exist.
        @param unliker - The signer representing the owner of the account to unlike with
        @param unliker_username - The username of the account to unlike with
        @param publication_author_username - The username of the account that owns the publication
        @param publication_type - The type of the publication to unlike
        @param publication_id - The id of the publication to unlike
    */
    entry fun unlike(
        unliker: &signer, 
        unliker_username: String, 
        publication_author_username: String,
        publication_type: String,
        publication_id: u64,
    ) acquires State, ModuleEventStore, Publications {

    }

    //==============================================================================================
    // Helper functions
    //==============================================================================================

    //==============================================================================================
    // View functions
    //==============================================================================================
    
    /*
        Returns the global timeline of posts. Timeline is sorted by most recent first.
        @param viewer_username - The username of the viewer
        @param page_size - The number of posts per page
        @param page_index - The index of the page to return
        @return - A tuple containing the account meta data of the post authors, the posts, and a 
            vector of booleans indicating whether the viewer has liked the post at the corresponding
            index
    */
    #[view]
    public fun get_global_timeline(
        viewer_username: String,
        page_size: u64,
        page_index: u64
    ): (vector<AccountMetaData>, vector<Post>, vector<bool>) acquires Publications, AccountMetaData, GlobalTimeline {

    }

    /*  
        Returns the timeline of posts from accounts that the username follows. Timeline is sorted by 
        most recent first.
        @param username - The username of the account to get the following timeline of
        @param viewer_username - The username of the viewer
        @param page_size - The number of posts per page
        @param page_index - The index of the page to return
        @return - A tuple containing the account meta data of the post authors, the posts, and a 
            vector of booleans indicating whether the viewer has liked the post at the corresponding
            index
    */
    #[view]
    public fun get_following_timeline(
        username: String, 
        viewer_username: String,
        page_size: u64, 
        page_index: u64
    ): (vector<AccountMetaData>, vector<Post>, vector<bool>) acquires State, Publications, AccountMetaData, GlobalTimeline {

    }

    /*
        Returns the timeline of posts from the account associated with the given username. Posts are
        sorted by most recent first.
        @param username - The username of the account to get the timeline of
        @param viewer_username - The username of the viewer
        @param page_size - The number of posts per page
        @param page_index - The index of the page to return
        @return - A tuple containing the account meta data of the account, the posts, and a 
            vector of booleans indicating whether the viewer has liked the post at the corresponding
            index
    */
    #[view]
    public fun get_account_posts(
        username: String,
        viewer_username: String,
        page_size: u64,
        page_index: u64
    ): (AccountMetaData, vector<Post>, vector<bool>) acquires State, Publications, AccountMetaData {

    }   

    /*
        Returns the timeline of comments from the account associated with the given username. 
        Comments are sorted by most recent first.
        @param username - The username of the account to get the timeline of
        @param viewer_username - The username of the viewer
        @param page_size - The number of comments per page
        @param page_index - The index of the page to return
        @return - A tuple containing the account meta data of the account, the comments, the posts 
            that the comments are on, the account meta data of the post authors, a vector of 
            booleans indicating whether the viewer has liked the comment at the corresponding index, 
            and a vector of booleans indicating whether the viewer has liked the post at the
            corresponding index
    */
    #[view]
    public fun get_account_comments(
        username: String, 
        viewer_username: String,
        page_size: u64,
        page_index: u64
    ): (AccountMetaData, vector<Comment>, vector<Post>, vector<AccountMetaData>, vector<bool>, vector<bool>) acquires State, Publications, AccountMetaData {

    }

    /*
        Returns the timeline of liked posts from the account associated with the given username. Likes are
        sorted by most recent first.
        @param username - The username of the account to get the timeline of
        @param viewer_username - The username of the viewer
        @param page_size - The number of likes per page
        @param page_index - The index of the page to return
        @return - A tuple containing the account meta data of the account, the liked posts, the account 
            meta data of the post authors, and a vector of booleans indicating whether the viewer has 
            liked the post at the corresponding index
    */
    #[view]
    public fun get_account_liked_posts(
        username: String, 
        viewer_username: String,
        page_size: u64,
        page_index: u64
    ): (AccountMetaData, vector<Post>, vector<AccountMetaData>, vector<bool>) acquires State, Publications, AccountMetaData {

    }

    /*
        Returns the timeline of liked comments from the account associated with the given username. Likes are
        sorted by most recent first.
        @param username - The username of the account to get the timeline of
        @param viewer_username - The username of the viewer
        @param page_size - The number of likes per page
        @param page_index - The index of the page to return
        @return - A tuple containing the account meta data of the account, the liked comments, the account 
            meta data of the comment authors, the posts that the comments are on, the account meta data 
            of the post authors, a vector of booleans indicating whether the viewer has liked the comment 
            at the corresponding index, and a vector of booleans indicating whether the viewer has liked 
            the post at the corresponding index
    */
    #[view]
    public fun get_account_liked_comments(
        username: String, 
        viewer_username: String,
        page_size: u64,
        page_index: u64
    ): (AccountMetaData, vector<Comment>, vector<AccountMetaData>, vector<Post>, vector<AccountMetaData>, vector<bool>, vector<bool>) acquires State, Publications, AccountMetaData {

    }

    /*
        Returns the account meta data of the account associated with the given username as well as a 
        vector of account meta data of the accounts that follow the account. Accounts are sorted by
        most recent first.
        @param username - The username of the account to get the followers of
        @param page_size - The number of followers per page
        @param page_index - The index of the page to return
        @return - A tuple containing the account meta data of the account and a vector of account 
            meta data of the accounts that follow the account
    */
    #[view]
    public fun get_account_followers(
        username: String, 
        page_size: u64,
        page_index: u64
    ): (AccountMetaData, vector<AccountMetaData>) acquires State, AccountMetaData {

    }

    /*
        Returns the account meta data of the account associated with the given username as well as a 
        vector of account meta data of the accounts that the account follows. Accounts are sorted by
        most recent first.
        @param username - The username of the account to get the followings of
        @param page_size - The number of followings per page
        @param page_index - The index of the page to return
        @return - A tuple containing the account meta data of the account and a vector of account 
            meta data of the accounts that the account follows
    */
    #[view]
    public fun get_account_followings(
        username: String,
        page_size: u64,
        page_index: u64
    ): (AccountMetaData, vector<AccountMetaData>) acquires State, AccountMetaData {

    }

    /*
        Returns the post created by the given username along with other information about the post.
        @param username - The username of the account that created the post
        @param viewer_username - The username of the viewer
        @param post_id - The id of the post
        @param page_size - The number of comments per page
        @param page_index - The index of the page to return
        @return - A tuple containing the account meta data of the post author, the post, a boolean 
            indicating whether the viewer has liked the post, the comments on the post, and the 
            account meta data of the comment authors
    */
    #[view]
    public fun get_post(
        username: String,
        viewer_username: String,
        post_id: u64,
        page_size: u64,
        page_index: u64
    ): (AccountMetaData, Post, bool, vector<Comment>, vector<AccountMetaData>) acquires State, Publications, AccountMetaData {

    }

    //==============================================================================================
    // Validation functions
    //==============================================================================================

    //==============================================================================================
    // Tests - DO NOT MODIFY
    //==============================================================================================

    #[test(admin = @overmind, user1 = @0xA)]
    fun init_module_test_success(
        admin: &signer,
        user1: &signer
    ) acquires State, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");

        assert!(exists<State>(expected_resource_account_address), 0);
        assert!(exists<ModuleEventStore>(expected_resource_account_address), 0);
        assert!(exists<GlobalTimeline>(expected_resource_account_address), 0);

        let state = borrow_global<State>(expected_resource_account_address);
        assert!(
            account::get_signer_capability_address(&state.signer_cap) == expected_resource_account_address,
            0
        );

        let expected_account_collection_address = collection::create_collection_address(
            &expected_resource_account_address, 
            &string::utf8(b"account collection")
        );
        assert!(
            state.account_collection_address == expected_account_collection_address,
            0
        );

        let account_collection_object = object::address_to_object<collection::Collection>(
            expected_account_collection_address
        );
        assert!(
            collection::creator(account_collection_object) == expected_resource_account_address,
            0
        );
        assert!(
            collection::description(account_collection_object) == string::utf8(b"account collection description"),
            0
        );
        assert!(
            collection::name(account_collection_object) == string::utf8(b"account collection"),
            0
        );
        assert!(
            collection::uri(account_collection_object) == string::utf8(b"account collection uri"),
            0
        );
        assert!(
            option::is_some(&collection::count<collection::Collection>(account_collection_object)),
            0
        );
        assert!(
            option::contains(&collection::count<collection::Collection>(account_collection_object), &0),
            0
        );

        let global_timeline = borrow_global<GlobalTimeline>(expected_resource_account_address);
        assert!(
            vector::length(&global_timeline.posts) == 0,
            0
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun create_account_test_success_create_one_account(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b"dan"), string::utf8(b"me.png"), vector[]);

        let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
        let state = borrow_global<State>(expected_resource_account_address);
        
        /* 
            - Check if the account address is registered correctly in the account registry
            - Check the account collection supply is correct (1)
        */
        {
            assert!(
                table::contains(&state.account_registry.accounts, account_username_1),
                0
            );

            let collection_address = state.account_collection_address;
            let account_collection_object = object::address_to_object<collection::Collection>(
                collection_address
            );
            assert!(
                option::contains(&collection::count<collection::Collection>(account_collection_object), &1),
                0
            );
        };

        /* 
            - Check if the account token address is stored correctly in the account registry
            - Check if the account token is created correctly
                - Check the account token name
                - Check the account token collection name
                - Check the account token description
                - Check the account token uri
                - Check the account token royalty
                - Check the account token owner
        */
        {
            let expected_account_token_address = token::create_token_address(
                &expected_resource_account_address, 
                &string::utf8(b"account collection"), 
                &account_username_1
            );
            assert!(
                table::borrow(&state.account_registry.accounts, account_username_1) == 
                    &expected_account_token_address,
                0
            );

            let account_token_object = object::address_to_object<token::Token>(
                expected_account_token_address
            );
            assert!(
                token::name(account_token_object) == account_username_1,
                0
            );
            assert!(
                token::collection_name(account_token_object) == string::utf8(b"account collection"),
                0
            );
            assert!(
                token::description(account_token_object) == string::utf8(b""),
                0
            );
            assert!(
                token::uri(account_token_object) == string::utf8(b""),
                0
            );
            assert!(
                option::is_none(&token::royalty(account_token_object)),
                0
            );
            assert!(
                object::is_owner(account_token_object, user_address_1),
                0
            );
        };

        /* 
            - Check if the account metadata is created correctly
                - Check the account metadata creation timestamp
                - Check the account metadata account address
                - Check the account metadata username
                - Check the account metadata profile picture uri
                - Check the account metadata bio
                - Check the account metadata follower token addresses
                - Check the account metadata following token addresses
                - Check the account metadata follower collection address
        */
        {
            let account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            let account_meta_data = borrow_global<AccountMetaData>(account_address);

            assert!(
                account_meta_data.creation_timestamp == timestamp::now_seconds(),
                0
            );
            assert!(
                account_meta_data.account_address == account_address,
                0
            );
            assert!(
                account_meta_data.username == account_username_1,
                0
            );
            assert!(
                account_meta_data.name == string::utf8(b"dan"),
                0
            );
            assert!(
                account_meta_data.profile_picture_uri == string::utf8(b"me.png"),
                0
            );
            assert!(
                account_meta_data.bio == string::utf8(b""),
                0
            );
            assert!(
                vector::length(&account_meta_data.follower_account_usernames) == 0,
                0
            );
            assert!(
                vector::length(&account_meta_data.following_account_usernames) == 0,
                0
            );
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        }
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsernameInvalidLength)]
    fun create_account_test_failure_username_too_short(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"");
        create_account(user1, account_username_1, string::utf8(b"dan"), string::utf8(b"me.png"), vector[]);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsernameInvalidLength)]
    fun create_account_test_failure_username_too_long(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"000000000000000000000000000000000");
        create_account(user1, account_username_1, string::utf8(b"dan"), string::utf8(b"me.png"), vector[]);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EProfilePictureUriInvalidLength)]
    fun create_account_test_failure_profile_pic_invalid_length(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let profile_pic_uri = string::utf8(b"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
        create_account(user1, account_username_1, string::utf8(b"dan"), profile_pic_uri, vector[]);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = ENameInvalidLength)]
    fun create_account_test_failure_name_invalid_length(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let name = string::utf8(b"0000000000000000000000000000000000000000000000000000000000000");
        create_account(user1, account_username_1, name, string::utf8(b""), vector[]);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun create_account_test_success_create_two_accounts(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b"joe"), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"tree hugger 24");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b"mysmile.jpeg"), vector[]);

        let expected_resource_account_address = 
            account::create_resource_address(&@overmind, b"decentralized platform");
        let state = borrow_global<State>(expected_resource_account_address);
        
        /* 
            - Check if the account address is registered correctly in the account registry
            - Check the account collection supply is correct (2)
        */
        {
            assert!(
                table::contains(&state.account_registry.accounts, account_username_1),
                0
            );

            let collection_address = state.account_collection_address;
            let account_collection_object = object::address_to_object<collection::Collection>(
                collection_address
            );
            assert!(
                option::contains(&collection::count<collection::Collection>(account_collection_object), &2),
                0
            );
        };

        /* 
            - Check if the account token address is stored correctly in the account registry
            - Check if the account token is created correctly
                - Check the account token name
                - Check the account token collection name
                - Check the account token description
                - Check the account token uri
                - Check the account token royalty
                - Check the account token owner
        */
        {
            let expected_account_token_address = token::create_token_address(
                &expected_resource_account_address, 
                &string::utf8(b"account collection"), 
                &account_username_1
            );
            assert!(
                table::borrow(&state.account_registry.accounts, account_username_1) == 
                    &expected_account_token_address,
                0
            );

            let account_token_object = object::address_to_object<token::Token>(
                expected_account_token_address
            );
            assert!(
                token::name(account_token_object) == account_username_1,
                0
            );
            assert!(
                token::collection_name(account_token_object) == string::utf8(b"account collection"),
                0
            );
            assert!(
                token::description(account_token_object) == string::utf8(b""),
                0
            );
            assert!(
                token::uri(account_token_object) == string::utf8(b""),
                0
            );
            assert!(
                option::is_none(&token::royalty(account_token_object)),
                0
            );
            assert!(
                object::is_owner(account_token_object, user_address_1),
                0
            );
        };

        /* 
            - Check if the account metadata is created correctly
                - Check the account metadata creation timestamp
                - Check the account metadata account address
                - Check the account metadata username
                - Check the account metadata profile picture uri
                - Check the account metadata bio
                - Check the account metadata follower token addresses
                - Check the account metadata following token addresses
                - Check the account metadata follower collection address

            - Check the account's follow collection
                - Check the account metadata follower collection creator
                - Check the account metadata follower collection description
                - Check the account metadata follower collection name
                - Check the account metadata follower collection uri
                - Check the account metadata follower collection supply
        */
        {
            let account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            let account_meta_data = borrow_global<AccountMetaData>(account_address);

            assert!(
                account_meta_data.creation_timestamp == timestamp::now_seconds(),
                0
            );
            assert!(
                account_meta_data.account_address == account_address,
                0
            );
            assert!(
                account_meta_data.username == account_username_1,
                0
            );
            assert!(
                account_meta_data.name == string::utf8(b"joe"),
                0
            );
            assert!(
                account_meta_data.profile_picture_uri == string::utf8(b""),
                0
            );
            assert!(
                account_meta_data.bio == string::utf8(b""),
                0
            );
            assert!(
                vector::length(&account_meta_data.follower_account_usernames) == 0,
                0
            );
            assert!(
                vector::length(&account_meta_data.following_account_usernames) == 0,
                0
            );
        };

        /* 
            - Check if the account token address is stored correctly in the account registry
            - Check if the account token is created correctly
                - Check the account token name
                - Check the account token collection name
                - Check the account token description
                - Check the account token uri
                - Check the account token royalty
                - Check the account token owner
        */
        {
            let expected_account_token_address = token::create_token_address(
                &expected_resource_account_address, 
                &string::utf8(b"account collection"), 
                &account_username_2
            );
            assert!(
                table::borrow(&state.account_registry.accounts, account_username_2) == 
                    &expected_account_token_address,
                0
            );

            let account_token_object = object::address_to_object<token::Token>(
                expected_account_token_address
            );
            assert!(
                token::name(account_token_object) == account_username_2,
                0
            );
            assert!(
                token::collection_name(account_token_object) == string::utf8(b"account collection"),
                0
            );
            assert!(
                token::description(account_token_object) == string::utf8(b""),
                0
            );
            assert!(
                token::uri(account_token_object) == string::utf8(b""),
                0
            );
            assert!(
                option::is_none(&token::royalty(account_token_object)),
                0
            );
            assert!(
                object::is_owner(account_token_object, user_address_1),
                0
            );
        };

        /* 
            - Check if the account metadata is created correctly
                - Check the account metadata creation timestamp
                - Check the account metadata account address
                - Check the account metadata username
                - Check the account metadata profile picture uri
                - Check the account metadata bio
                - Check the account metadata follower token addresses
                - Check the account metadata following token addresses
                - Check the account metadata follower collection address

            - Check the account's follow collection
                - Check the account metadata follower collection creator
                - Check the account metadata follower collection description
                - Check the account metadata follower collection name
                - Check the account metadata follower collection uri
                - Check the account metadata follower collection supply
        */
        {
            let account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_2
            );
            let account_meta_data = borrow_global<AccountMetaData>(account_address);

            assert!(
                account_meta_data.creation_timestamp == timestamp::now_seconds(),
                0
            );
            assert!(
                account_meta_data.account_address == account_address,
                0
            );
            assert!(
                account_meta_data.username == account_username_2,
                0
            );
            assert!(
                account_meta_data.name == string::utf8(b""),
                0
            );
            assert!(
                account_meta_data.profile_picture_uri == string::utf8(b"mysmile.jpeg"),
                0
            );
            assert!(
                account_meta_data.bio == string::utf8(b""),
                0
            );
            assert!(
                vector::length(&account_meta_data.follower_account_usernames) == 0,
                0
            );
            assert!(
                vector::length(&account_meta_data.following_account_usernames) == 0,
                0
            );
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 2,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        }
    }
    #[test(admin = @overmind, user1 = @0xA)]
    fun create_account_test_success_create_many_accounts(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"tree hugger 24");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);
        
        let account_username_3 = string::utf8(b"john");
        create_account(user1, account_username_3, string::utf8(b""), string::utf8(b""), vector[]);

        let expected_resource_account_address = 
            account::create_resource_address(&@overmind, b"decentralized platform");
        let state = borrow_global<State>(expected_resource_account_address);
        
        /* 
            - Check if the account address is registered correctly in the account registry
            - Check the account collection supply is correct (3)
        */
        {
            assert!(
                table::contains(&state.account_registry.accounts, account_username_1),
                0
            );

            let collection_address = state.account_collection_address;
            let account_collection_object = object::address_to_object<collection::Collection>(
                collection_address
            );
            assert!(
                option::contains(&collection::count<collection::Collection>(account_collection_object), &3),
                0
            );
        };

        /* 
            - Check if the account token address is stored correctly in the account registry
            - Check if the account token is created correctly
                - Check the account token name
                - Check the account token collection name
                - Check the account token description
                - Check the account token uri
                - Check the account token royalty
                - Check the account token owner
        */
        {
            let expected_account_token_address = token::create_token_address(
                &expected_resource_account_address, 
                &string::utf8(b"account collection"), 
                &account_username_1
            );
            assert!(
                table::borrow(&state.account_registry.accounts, account_username_1) == 
                    &expected_account_token_address,
                0
            );

            let account_token_object = object::address_to_object<token::Token>(
                expected_account_token_address
            );
            assert!(
                token::name(account_token_object) == account_username_1,
                0
            );
            assert!(
                token::collection_name(account_token_object) == string::utf8(b"account collection"),
                0
            );
            assert!(
                token::description(account_token_object) == string::utf8(b""),
                0
            );
            assert!(
                token::uri(account_token_object) == string::utf8(b""),
                0
            );
            assert!(
                option::is_none(&token::royalty(account_token_object)),
                0
            );
            assert!(
                object::is_owner(account_token_object, user_address_1),
                0
            );
        };

        /* 
            - Check if the account metadata is created correctly
                - Check the account metadata creation timestamp
                - Check the account metadata account address
                - Check the account metadata username
                - Check the account metadata profile picture uri
                - Check the account metadata bio
                - Check the account metadata follower token addresses
                - Check the account metadata following token addresses
                - Check the account metadata follower collection address

            - Check the account's follow collection
                - Check the account metadata follower collection creator
                - Check the account metadata follower collection description
                - Check the account metadata follower collection name
                - Check the account metadata follower collection uri
                - Check the account metadata follower collection supply
        */
        {
            let account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            let account_meta_data = borrow_global<AccountMetaData>(account_address);

            assert!(
                account_meta_data.creation_timestamp == timestamp::now_seconds(),
                0
            );
            assert!(
                account_meta_data.account_address == account_address,
                0
            );
            assert!(
                account_meta_data.username == account_username_1,
                0
            );
            assert!(
                account_meta_data.profile_picture_uri == string::utf8(b""),
                0
            );
            assert!(
                account_meta_data.bio == string::utf8(b""),
                0
            );
            assert!(
                vector::length(&account_meta_data.follower_account_usernames) == 0,
                0
            );
            assert!(
                vector::length(&account_meta_data.following_account_usernames) == 0,
                0
            );
        };

        /* 
            - Check if the account token address is stored correctly in the account registry
            - Check if the account token is created correctly
                - Check the account token name
                - Check the account token collection name
                - Check the account token description
                - Check the account token uri
                - Check the account token royalty
                - Check the account token owner
        */
        {
            let expected_account_token_address = token::create_token_address(
                &expected_resource_account_address, 
                &string::utf8(b"account collection"), 
                &account_username_2
            );
            assert!(
                table::borrow(&state.account_registry.accounts, account_username_2) == 
                    &expected_account_token_address,
                0
            );

            let account_token_object = object::address_to_object<token::Token>(
                expected_account_token_address
            );
            assert!(
                token::name(account_token_object) == account_username_2,
                0
            );
            assert!(
                token::collection_name(account_token_object) == string::utf8(b"account collection"),
                0
            );
            assert!(
                token::description(account_token_object) == string::utf8(b""),
                0
            );
            assert!(
                token::uri(account_token_object) == string::utf8(b""),
                0
            );
            assert!(
                option::is_none(&token::royalty(account_token_object)),
                0
            );
            assert!(
                object::is_owner(account_token_object, user_address_1),
                0
            );
        };

        /* 
            - Check if the account metadata is created correctly
                - Check the account metadata creation timestamp
                - Check the account metadata account address
                - Check the account metadata username
                - Check the account metadata profile picture uri
                - Check the account metadata bio
                - Check the account metadata follower token addresses
                - Check the account metadata following token addresses
                - Check the account metadata follower collection address

            - Check the account's follow collection
                - Check the account metadata follower collection creator
                - Check the account metadata follower collection description
                - Check the account metadata follower collection name
                - Check the account metadata follower collection uri
                - Check the account metadata follower collection supply
        */
        {
            let account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_2
            );
            let account_meta_data = borrow_global<AccountMetaData>(account_address);

            assert!(
                account_meta_data.creation_timestamp == timestamp::now_seconds(),
                0
            );
            assert!(
                account_meta_data.account_address == account_address,
                0
            );
            assert!(
                account_meta_data.username == account_username_2,
                0
            );
            assert!(
                account_meta_data.profile_picture_uri == string::utf8(b""),
                0
            );
            assert!(
                account_meta_data.bio == string::utf8(b""),
                0
            );
            assert!(
                vector::length(&account_meta_data.follower_account_usernames) == 0,
                0
            );
            assert!(
                vector::length(&account_meta_data.following_account_usernames) == 0,
                0
            );
        };

        /* 
            - Check if the account token address is stored correctly in the account registry
            - Check if the account token is created correctly
                - Check the account token name
                - Check the account token collection name
                - Check the account token description
                - Check the account token uri
                - Check the account token royalty
                - Check the account token owner
        */
        {
            let expected_account_token_address = token::create_token_address(
                &expected_resource_account_address, 
                &string::utf8(b"account collection"), 
                &account_username_3
            );
            assert!(
                table::borrow(&state.account_registry.accounts, account_username_3) == 
                    &expected_account_token_address,
                0
            );

            let account_token_object = object::address_to_object<token::Token>(
                expected_account_token_address
            );
            assert!(
                token::name(account_token_object) == account_username_3,
                0
            );
            assert!(
                token::collection_name(account_token_object) == string::utf8(b"account collection"),
                0
            );
            assert!(
                token::description(account_token_object) == string::utf8(b""),
                0
            );
            assert!(
                token::uri(account_token_object) == string::utf8(b""),
                0
            );
            assert!(
                option::is_none(&token::royalty(account_token_object)),
                0
            );
            assert!(
                object::is_owner(account_token_object, user_address_1),
                0
            );
        };

        /* 
            - Check if the account metadata is created correctly
                - Check the account metadata creation timestamp
                - Check the account metadata account address
                - Check the account metadata username
                - Check the account metadata profile picture uri
                - Check the account metadata bio
                - Check the account metadata follower token addresses
                - Check the account metadata following token addresses
                - Check the account metadata follower collection address

            - Check the account's follow collection
                - Check the account metadata follower collection creator
                - Check the account metadata follower collection description
                - Check the account metadata follower collection name
                - Check the account metadata follower collection uri
                - Check the account metadata follower collection supply
        */
        {
            let account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_3
            );
            let account_meta_data = borrow_global<AccountMetaData>(account_address);

            assert!(
                account_meta_data.creation_timestamp == timestamp::now_seconds(),
                0
            );
            assert!(
                account_meta_data.account_address == account_address,
                0
            );
            assert!(
                account_meta_data.username == account_username_3,
                0
            );
            assert!(
                account_meta_data.profile_picture_uri == string::utf8(b""),
                0
            );
            assert!(
                account_meta_data.bio == string::utf8(b""),
                0
            );
            assert!(
                vector::length(&account_meta_data.follower_account_usernames) == 0,
                0
            );
            assert!(
                vector::length(&account_meta_data.following_account_usernames) == 0,
                0
            );
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 3,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        }
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun update_name_test_success_update_name_once(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let name = string::utf8(b"Larry Joe");
        update_name(user1, account_username_1, name);

        let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
        let state = borrow_global<State>(expected_resource_account_address);

        {
            let account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );

            let account_meta_data = borrow_global_mut<AccountMetaData>(account_address);
            assert!(
                account_meta_data.name == name,
                0
            );
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        }
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = ENameInvalidLength, location = Self)]
    fun update_name_test_failure_too_long(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let name = string::utf8(b"0000000000000000000000000000000000000000000000000000000000000");
        update_name(user1, account_username_1, name);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EAccountDoesNotOwnUsername, location = Self)]
    fun update_name_test_failure_account_does_not_owner_username(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let name = string::utf8(b"0");
        update_name(admin, account_username_1, name);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsernameNotRegistered, location = Self)]
    fun update_name_test_failure_username_not_registered(
        admin: &signer,
        user1: &signer
    ) acquires State, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");

        let name = string::utf8(b"0");
        update_name(user1, account_username_1, name);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun update_bio_test_success_update_bio_once(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let bio = string::utf8(b"Hello, I am a twitter clone account");
        update_bio(user1, account_username_1, bio);

        let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
        let state = borrow_global<State>(expected_resource_account_address);

        {
            let account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );

            let account_meta_data = borrow_global_mut<AccountMetaData>(account_address);
            assert!(
                account_meta_data.bio == bio,
                0
            );
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        }
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun update_bio_test_success_update_bio_many_times(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        {
            let bio_1 = string::utf8(b"Hello, I am a twitter clone account");
            update_bio(user1, account_username_1, bio_1);

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );

            let account_meta_data = borrow_global_mut<AccountMetaData>(account_address);
            assert!(
                account_meta_data.bio == bio_1,
                0
            );
        };

        {
            let bio_2 = string::utf8(b"Hello, I am a twitter clone account. I am a cool guy");
            update_bio(user1, account_username_1, bio_2);

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );

            let account_meta_data = borrow_global_mut<AccountMetaData>(account_address);
            assert!(
                account_meta_data.bio == bio_2,
                0
            );
        };

        {
            let bio_3 = string::utf8(b"Hello, I am a twitter clone account. I am a cool guy. I am a cool guy");
            update_bio(user1, account_username_1, bio_3);

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );

            let account_meta_data = borrow_global_mut<AccountMetaData>(account_address);
            assert!(
                account_meta_data.bio == bio_3,
                0
            );
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        }
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun update_profile_picture_test_picture_update_once(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let profile_picture_uri = string::utf8(b"picture.kahm");
        update_profile_picture(user1, account_username_1, profile_picture_uri);

        let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
        let state = borrow_global<State>(expected_resource_account_address);

        {
            let account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );

            let account_meta_data = borrow_global_mut<AccountMetaData>(account_address);
            assert!(
                account_meta_data.profile_picture_uri == profile_picture_uri,
                0
            );
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        }
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun update_profile_picture_test_picture_update_many_times(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        {
            let profile_picture_uri = string::utf8(b"picture.kahm");
            update_profile_picture(user1, account_username_1, profile_picture_uri);

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );

            let account_meta_data = borrow_global_mut<AccountMetaData>(account_address);
            assert!(
                account_meta_data.profile_picture_uri == profile_picture_uri,
                0
            );
        };

        {
            let profile_picture_uri = string::utf8(b"myface.kahm");
            update_profile_picture(user1, account_username_1, profile_picture_uri);

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );

            let account_meta_data = borrow_global_mut<AccountMetaData>(account_address);
            assert!(
                account_meta_data.profile_picture_uri == profile_picture_uri,
                0
            );
        };

        {
            let profile_picture_uri = string::utf8(b"myface.kahm");
            update_profile_picture(user1, account_username_1, profile_picture_uri);

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );

            let account_meta_data = borrow_global_mut<AccountMetaData>(account_address);
            assert!(
                account_meta_data.profile_picture_uri == profile_picture_uri,
                0
            );
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        }
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EProfilePictureUriInvalidLength, location = Self)]
    fun update_profile_pic_test_failure_too_long(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let profile_pic_uri = string::utf8(b"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
        update_profile_picture(user1, account_username_1, profile_pic_uri);
    }
    
    #[test(admin = @overmind, user1 = @0xA)]
    fun post_test_success_one_post(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        {
            let post_content = string::utf8(b"myopinion.kahm");
            post(user1, account_username_1, post_content);

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);
            let account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );

            let publications = borrow_global<Publications>(account_address);
            let posts = &publications.posts;
            assert!(
                vector::length(posts) == 1,
                0
            );

            let post = vector::borrow(posts, 0);
            assert!(
                post.timestamp == timestamp::now_seconds(),
                0
            );
            assert!(
                post.id == 0,
                0
            );
            assert!(
                post.content == post_content,
                0
            );
            assert!(
                vector::length(&post.comments) == 0,
                0
            );
            assert!(
                vector::length(&post.likes) == 0,
                0
            );
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        }
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun post_test_success_many_posts(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        {
            let post_content = string::utf8(b"myopinion.kahm");
            post(user1, account_username_1, post_content);

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);
            let account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );

            let publications = borrow_global<Publications>(account_address);
            let posts = &publications.posts;
            assert!(
                vector::length(posts) == 1,
                0
            );

            let post = vector::borrow(posts, 0);
            assert!(
                post.timestamp == timestamp::now_seconds(),
                0
            );
            assert!(
                post.id == 0,
                0
            );
            assert!(
                post.content == post_content,
                0
            );
            assert!(
                vector::length(&post.comments) == 0,
                0
            );
            assert!(
                vector::length(&post.likes) == 0,
                0
            );
        };

        {
            let post_content = string::utf8(b"mypostcontent.kahm");
            post(user1, account_username_1, post_content);

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);
            let account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );

            let publications = borrow_global<Publications>(account_address);
            let posts = &publications.posts;
            assert!(
                vector::length(posts) == 2,
                0
            );

            let post = vector::borrow(posts, 1);
            assert!(
                post.timestamp == timestamp::now_seconds(),
                0
            );
            assert!(
                post.id == 1,
                0
            );
            assert!(
                post.content == post_content,
                0
            );
            assert!(
                vector::length(&post.comments) == 0,
                0
            );
            assert!(
                vector::length(&post.likes) == 0,
                0
            );
        };
        {
            let post_content = string::utf8(b"nothing.kahm");
            post(user1, account_username_1, post_content);

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);
            let account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );

            let publications = borrow_global<Publications>(account_address);
            let posts = &publications.posts;
            assert!(
                vector::length(posts) == 3,
                0
            );

            let post = vector::borrow(posts, 2);
            assert!(
                post.timestamp == timestamp::now_seconds(),
                0
            );
            assert!(
                post.id == 2,
                0
            );
            assert!(
                post.content == post_content,
                0
            );
            assert!(
                vector::length(&post.comments) == 0,
                0
            );
            assert!(
                vector::length(&post.likes) == 0,
                0
            );
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 3,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        }
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun comment_test_success_one_comment_on_self_post(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"myopinion.kahm");
        post(user1, account_username_1, post_content);

        {
            let comment_content = string::utf8(b"mycomment.kahm");
            comment(
                user1, 
                account_username_1, 
                comment_content, 
                account_username_1, 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let commenter_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            /* 
                - Check the commenter side
                    - Correct number of comments
                    - Correct comment
                        - Correct timestamp
                        - Correct id
                        - Correct content uri
                        - Correct number of comments
                        - Correct number of likes
                        - Correct reference
                            - Correct publication author account address
                            - Correct publication index
                            - Correct publication type
            */
            let (author_account_address, publication_index) = {
                let publications = borrow_global<Publications>(commenter_account_address);
                let comments = &publications.comments;
                assert!(
                    vector::length(comments) == 1,
                    0
                );

                let comment = vector::borrow(comments, 0);
                assert!(
                    comment.timestamp == timestamp::now_seconds(),
                    0
                );
                assert!(
                    comment.id == 0,
                    0
                );
                assert!(
                    comment.content == comment_content,
                    0
                );
                assert!(
                    vector::length(&comment.likes) == 0,
                    0
                );
                assert!(
                    comment.reference.publication_author_account_address == author_account_address,
                    0
                );
                assert!(
                    comment.reference.publication_index == 0,
                    0
                );
                assert!(
                    comment.reference.publication_type == string::utf8(b"post"),
                    0
                );

                (
                    comment.reference.publication_author_account_address,
                    comment.reference.publication_index
                )
            };

            /* 
                - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, publication_index);
                let comments = &post.comments;
                assert!(
                    vector::length(comments) == 1,
                    0
                );

                let comment_reference = vector::borrow(comments, 0);
                assert!(
                    comment_reference.publication_author_account_address == commenter_account_address,
                    0
                );
                assert!(
                    comment_reference.publication_index == 0,
                    0
                );
                assert!(
                    comment_reference.publication_type == string::utf8(b"comment"),
                    0
                );
            };
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        }
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun comment_test_success_one_comment_on_other_post(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"myopinion.kahm");
        post(user1, account_username_1, post_content);

        {
            let comment_content = string::utf8(b"mycomment.kahm");
            comment(
                user1, 
                account_username_2, 
                comment_content, 
                account_username_1, 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let commenter_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_2
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            /* 
                - Check the commenter side
                    - Correct number of comments
                    - Correct comment
                        - Correct timestamp
                        - Correct id
                        - Correct content uri
                        - Correct number of comments
                        - Correct number of likes
                        - Correct reference
                            - Correct publication author account address
                            - Correct publication index
                            - Correct publication type
            */
            let (author_account_address, publication_index) = {
                let publications = borrow_global<Publications>(commenter_account_address);
                let comments = &publications.comments;
                assert!(
                    vector::length(comments) == 1,
                    0
                );

                let comment = vector::borrow(comments, 0);
                assert!(
                    comment.timestamp == timestamp::now_seconds(),
                    0
                );
                assert!(
                    comment.id == 0,
                    0
                );
                assert!(
                    comment.content == comment_content,
                    0
                );
                assert!(
                    vector::length(&comment.likes) == 0,
                    0
                );
                assert!(
                    comment.reference.publication_author_account_address == author_account_address,
                    0
                );
                assert!(
                    comment.reference.publication_index == 0,
                    0
                );
                assert!(
                    comment.reference.publication_type == string::utf8(b"post"),
                    0
                );

                (
                    comment.reference.publication_author_account_address,
                    comment.reference.publication_index
                )
            };

            /* 
                - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, publication_index);
                let comments = &post.comments;
                assert!(
                    vector::length(comments) == 1,
                    0
                );

                let comment_reference = vector::borrow(comments, 0);
                assert!(
                    comment_reference.publication_author_account_address == commenter_account_address,
                    0
                );
                assert!(
                    comment_reference.publication_index == 0,
                    0
                );
                assert!(
                    comment_reference.publication_type == string::utf8(b"comment"),
                    0
                );
            };
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 2,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        }
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun comment_test_success_multiple_comments_on_other_post(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"myopinion.kahm");
        post(user1, account_username_1, post_content);

        {
            let comment_content = string::utf8(b"mycomment.kahm");
            comment(
                user1, 
                account_username_2, 
                comment_content, 
                account_username_1, 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let commenter_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_2
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            /* 
                - Check the commenter side
                    - Correct number of comments
                    - Correct comment
                        - Correct timestamp
                        - Correct id
                        - Correct content uri
                        - Correct number of comments
                        - Correct number of likes
                        - Correct reference
                            - Correct publication author account address
                            - Correct publication index
                            - Correct publication type
            */
            let (author_account_address, publication_index) = {
                let publications = borrow_global<Publications>(commenter_account_address);
                let comments = &publications.comments;
                assert!(
                    vector::length(comments) == 1,
                    0
                );

                let comment = vector::borrow(comments, 0);
                assert!(
                    comment.timestamp == timestamp::now_seconds(),
                    0
                );
                assert!(
                    comment.id == 0,
                    0
                );
                assert!(
                    comment.content == comment_content,
                    0
                );
                assert!(
                    vector::length(&comment.likes) == 0,
                    0
                );
                assert!(
                    comment.reference.publication_author_account_address == author_account_address,
                    0
                );
                assert!(
                    comment.reference.publication_index == 0,
                    0
                );
                assert!(
                    comment.reference.publication_type == string::utf8(b"post"),
                    0
                );

                (
                    comment.reference.publication_author_account_address,
                    comment.reference.publication_index
                )
            };

            /* 
                - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, publication_index);
                let comments = &post.comments;
                assert!(
                    vector::length(comments) == 1,
                    0
                );

                let comment_reference = vector::borrow(comments, 0);
                assert!(
                    comment_reference.publication_author_account_address == commenter_account_address,
                    0
                );
                assert!(
                    comment_reference.publication_index == 0,
                    0
                );
                assert!(
                    comment_reference.publication_type == string::utf8(b"comment"),
                    0
                );
            };
        };

        {
            let comment_content = string::utf8(b"mycomment2.kahm");
            comment(
                user1, 
                account_username_2, 
                comment_content, 
                account_username_1, 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let commenter_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_2
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            /* 
                - Check the commenter side
                    - Correct number of comments
                    - Correct comment
                        - Correct timestamp
                        - Correct id
                        - Correct content uri
                        - Correct number of comments
                        - Correct number of likes
                        - Correct reference
                            - Correct publication author account address
                            - Correct publication index
                            - Correct publication type
            */
            let (author_account_address, publication_index) = {
                let publications = borrow_global<Publications>(commenter_account_address);
                let comments = &publications.comments;
                assert!(
                    vector::length(comments) == 2,
                    0
                );

                let comment = vector::borrow(comments, 1);
                assert!(
                    comment.timestamp == timestamp::now_seconds(),
                    0
                );
                assert!(
                    comment.id == 1,
                    0
                );
                assert!(
                    comment.content == comment_content,
                    0
                );
                assert!(
                    vector::length(&comment.likes) == 0,
                    0
                );
                assert!(
                    comment.reference.publication_author_account_address == author_account_address,
                    0
                );
                assert!(
                    comment.reference.publication_index == 0,
                    0
                );
                assert!(
                    comment.reference.publication_type == string::utf8(b"post"),
                    0
                );

                (
                    comment.reference.publication_author_account_address,
                    comment.reference.publication_index
                )
            };

            /* 
                - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, publication_index);
                let comments = &post.comments;
                assert!(
                    vector::length(comments) == 2,
                    0
                );

                let comment_reference = vector::borrow(comments, 1);
                assert!(
                    comment_reference.publication_author_account_address == commenter_account_address,
                    0
                );
                assert!(
                    comment_reference.publication_index == 1,
                    0
                );
                assert!(
                    comment_reference.publication_type == string::utf8(b"comment"),
                    0
                );
            };
        };

        {
            let comment_content = string::utf8(b"mycomment3.kahm");
            comment(
                user1, 
                account_username_2, 
                comment_content, 
                account_username_1, 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let commenter_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_2
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            /* 
                - Check the commenter side
                    - Correct number of comments
                    - Correct comment
                        - Correct timestamp
                        - Correct id
                        - Correct content uri
                        - Correct number of comments
                        - Correct number of likes
                        - Correct reference
                            - Correct publication author account address
                            - Correct publication index
                            - Correct publication type
            */
            let (author_account_address, publication_index) = {
                let publications = borrow_global<Publications>(commenter_account_address);
                let comments = &publications.comments;
                assert!(
                    vector::length(comments) == 3,
                    0
                );

                let comment = vector::borrow(comments, 2);
                assert!(
                    comment.timestamp == timestamp::now_seconds(),
                    0
                );
                assert!(
                    comment.id == 2,
                    0
                );
                assert!(
                    comment.content == comment_content,
                    0
                );
                assert!(
                    vector::length(&comment.likes) == 0,
                    0
                );
                assert!(
                    comment.reference.publication_author_account_address == author_account_address,
                    0
                );
                assert!(
                    comment.reference.publication_index == 0,
                    0
                );
                assert!(
                    comment.reference.publication_type == string::utf8(b"post"),
                    0
                );

                (
                    comment.reference.publication_author_account_address,
                    comment.reference.publication_index
                )
            };

            /* 
                - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, publication_index);
                let comments = &post.comments;
                assert!(
                    vector::length(comments) == 3,
                    0
                );

                let comment_reference = vector::borrow(comments, 2);
                assert!(
                    comment_reference.publication_author_account_address == commenter_account_address,
                    0
                );
                assert!(
                    comment_reference.publication_index == 2,
                    0
                );
                assert!(
                    comment_reference.publication_type == string::utf8(b"comment"),
                    0
                );
            };
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 2,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 3,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        }
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun like_test_success_one_like_on_self_post(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"myopinion.kahm");
        post(user1, account_username_1, post_content);

        {
            like(
                user1, 
                account_username_1, 
                account_username_1, 
                string::utf8(b"post"), 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let liker_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            /* 
                - Check the liker side
                    - Correct number of comments
                    - Correct comment
                        - Correct timestamp
                        - Correct id
                        - Correct content uri
                        - Correct number of comments
                        - Correct number of likes
                        - Correct reference
                            - Correct publication author account address
                            - Correct publication index
                            - Correct publication type
            */
            let (author_account_address, publication_index) = {
                let publications = borrow_global<Publications>(liker_account_address);
                let likes = &publications.likes;
                assert!(
                    vector::length(likes) == 1,
                    0
                );

                let like = vector::borrow(likes, 0);
                assert!(
                    like.timestamp == timestamp::now_seconds(),
                    0
                );
                assert!(
                    like.reference.publication_author_account_address == author_account_address,
                    0
                );
                assert!(
                    like.reference.publication_index == 0,
                    0
                );
                assert!(
                    like.reference.publication_type == string::utf8(b"post"),
                    0
                );

                (
                    like.reference.publication_author_account_address,
                    like.reference.publication_index
                )
            };

            /* 
                - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, publication_index);
                let likes = &post.likes;
                assert!(
                    vector::length(likes) == 1,
                    0
                );

                let actual_liker_account_username = vector::borrow(likes, 0);
                assert!(
                    actual_liker_account_username == &account_username_1,
                    0
                );
            };
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun like_test_success_one_like_on_other_post(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"myopinion.kahm");
        post(user1, account_username_1, post_content);

        {
            like(
                user1, 
                account_username_2, 
                account_username_1, 
                string::utf8(b"post"), 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let liker_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_2
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            /* 
                - Check the liker side
                    - Correct number of comments
                    - Correct comment
                        - Correct timestamp
                        - Correct id
                        - Correct content uri
                        - Correct number of comments
                        - Correct number of likes
                        - Correct reference
                            - Correct publication author account address
                            - Correct publication index
                            - Correct publication type
            */
            let (author_account_address, publication_index) = {
                let publications = borrow_global<Publications>(liker_account_address);
                let likes = &publications.likes;
                assert!(
                    vector::length(likes) == 1,
                    0
                );

                let like = vector::borrow(likes, 0);
                assert!(
                    like.timestamp == timestamp::now_seconds(),
                    0
                );

                assert!(
                    like.reference.publication_author_account_address == author_account_address,                    0
                );
                assert!(
                    like.reference.publication_index == 0,
                    0
                );
                assert!(
                    like.reference.publication_type == string::utf8(b"post"),
                    0
                );

                (
                    like.reference.publication_author_account_address,
                    like.reference.publication_index
                )
            };

            /* 
                - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, publication_index);
                let likes = &post.likes;
                assert!(
                    vector::length(likes) == 1,
                    0
                );

                let actual_liker_account_username = vector::borrow(likes, 0);
                assert!(
                    actual_liker_account_username == &account_username_2,
                    0
                );
            };
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 2,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun like_test_success_multiple_likes_on_other_post(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_3 = string::utf8(b"mind_slayer_3002");
        create_account(user1, account_username_3, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content = string::utf8(b"myopinion.kahm");
        post(user1, account_username_1, post_content);

        {
            like(
                user1, 
                account_username_2, 
                account_username_1, 
                string::utf8(b"post"), 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let liker_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_2
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            /* 
                - Check the liker side
                    - Correct number of comments
                    - Correct comment
                        - Correct timestamp
                        - Correct id
                        - Correct content uri
                        - Correct number of comments
                        - Correct number of likes
                        - Correct reference
                            - Correct publication author account address
                            - Correct publication index
                            - Correct publication type
            */
            let (author_account_address, publication_index) = {
                let publications = borrow_global<Publications>(liker_account_address);
                let likes = &publications.likes;
                assert!(
                    vector::length(likes) == 1,
                    0
                );

                let like = vector::borrow(likes, 0);
                assert!(
                    like.timestamp == timestamp::now_seconds(),
                    0
                );

                assert!(
                    like.reference.publication_author_account_address == author_account_address,
                    0
                );
                assert!(                    like.reference.publication_index == 0,
                    0
                );
                assert!(
                    like.reference.publication_type == string::utf8(b"post"),
                    0
                );

                (
                    like.reference.publication_author_account_address,
                    like.reference.publication_index
                )
            };

            /* 
                - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, publication_index);
                let likes = &post.likes;
                assert!(
                    vector::length(likes) == 1,
                    0
                );

                let actual_liker_account_username = vector::borrow(likes, 0);
                assert!(
                    actual_liker_account_username == &account_username_2,
                    0
                );
            };
        };

        {
            like(
                user1, 
                account_username_3, 
                account_username_1, 
                string::utf8(b"post"), 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let liker_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_3
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            /* 
                - Check the liker side
                    - Correct number of comments
                    - Correct comment
                        - Correct timestamp
                        - Correct id
                        - Correct content uri
                        - Correct number of comments
                        - Correct number of likes
                        - Correct reference
                            - Correct publication author account address
                            - Correct publication index
                            - Correct publication type
            */
            let (author_account_address, publication_index) = {
                let publications = borrow_global<Publications>(liker_account_address);
                let likes = &publications.likes;
                assert!(
                    vector::length(likes) == 1,
                    0
                );

                let like = vector::borrow(likes, 0);
                assert!(
                    like.timestamp == timestamp::now_seconds(),
                    0
                );

                assert!(
                    like.reference.publication_author_account_address == author_account_address,
                    0
                );
                assert!(
                    like.reference.publication_index == 0,
                    0
                );                assert!(
                    like.reference.publication_type == string::utf8(b"post"),
                    0
                );

                (
                    like.reference.publication_author_account_address,
                    like.reference.publication_index
                )
            };

            /* 
                - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, publication_index);
                let likes = &post.likes;
                assert!(
                    vector::length(likes) == 2,
                    0
                );

                let actual_liker_account_username = vector::borrow(likes, 1);
                assert!(
                    actual_liker_account_username == &account_username_3,
                    0
                );
            };
        };

        {
            like(
                user1, 
                account_username_1, 
                account_username_1, 
                string::utf8(b"post"), 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let liker_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            /* 
                - Check the liker side
                    - Correct number of comments
                    - Correct comment
                        - Correct timestamp
                        - Correct id
                        - Correct content uri
                        - Correct number of comments
                        - Correct number of likes
                        - Correct reference
                            - Correct publication author account address
                            - Correct publication index
                            - Correct publication type
            */
            let (author_account_address, publication_index) = {
                let publications = borrow_global<Publications>(liker_account_address);
                let likes = &publications.likes;
                assert!(
                    vector::length(likes) == 1,
                    0
                );

                let like = vector::borrow(likes, 0);
                assert!(
                    like.timestamp == timestamp::now_seconds(),
                    0
                );

                assert!(
                    like.reference.publication_author_account_address == author_account_address,
                    0
                );
                assert!(
                    like.reference.publication_index == 0,
                    0
                );
                assert!(
                    like.reference.publication_type == string::utf8(b"post"),
                    0                );

                (
                    like.reference.publication_author_account_address,
                    like.reference.publication_index
                )
            };

            /* 
                - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, publication_index);
                let likes = &post.likes;
                assert!(
                    vector::length(likes) == 3,
                    0
                );

                let actual_liker_account_username = vector::borrow(likes, 2);
                assert!(
                    actual_liker_account_username == &account_username_1,
                    0
                );
            };
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 3,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 3,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun like_test_success_one_like_on_self_comment(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"myopinion.kahm");
        post(user1, account_username_1, post_content);

        let comment_content = string::utf8(b"mycomment.kahm");
        comment(
            user1, 
            account_username_1,
            comment_content,
            account_username_1,
            0
        );

        {
            like(
                user1, 
                account_username_1, 
                account_username_1, 
                string::utf8(b"comment"), 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let liker_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            /* 
                - Check the liker side
                    - Correct number of comments
                    - Correct comment
                        - Correct timestamp
                        - Correct id
                        - Correct content uri
                        - Correct number of comments
                        - Correct number of likes
                        - Correct reference
                            - Correct publication author account address
                            - Correct publication index
                            - Correct publication type
            */
            let (author_account_address, publication_index) = {
                let publications = borrow_global<Publications>(liker_account_address);
                let likes = &publications.likes;
                assert!(
                    vector::length(likes) == 1,
                    0
                );

                let like = vector::borrow(likes, 0);
                assert!(
                    like.timestamp == timestamp::now_seconds(),
                    0
                );

                assert!(
                    like.reference.publication_author_account_address == author_account_address,
                    0
                );
                assert!(
                    like.reference.publication_index == 0,
                    0
                );
                assert!(
                    like.reference.publication_type == string::utf8(b"comment"),
                    0
                );

                (                    like.reference.publication_author_account_address,
                    like.reference.publication_index
                )
            };

            /* 
                - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let comments = &publications.comments;
                let comment = vector::borrow(comments, publication_index);
                let likes = &comment.likes;
                assert!(
                    vector::length(likes) == 1,
                    0
                );

                let actual_liker_account_username = vector::borrow(likes, 0);
                assert!(
                    actual_liker_account_username == &account_username_1,
                    0
                );
            };
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun like_test_success_one_like_on_other_comment(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"myopinion.kahm");
        post(user1, account_username_1, post_content);

        let comment_content = string::utf8(b"mycomment.kahm");
        comment(
            user1, 
            account_username_1,
            comment_content,
            account_username_1,
            0
        );

        {
            like(
                user1, 
                account_username_2, 
                account_username_1, 
                string::utf8(b"comment"), 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let liker_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_2
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            /* 
                - Check the liker side
                    - Correct number of comments
                    - Correct comment
                        - Correct timestamp
                        - Correct id
                        - Correct content uri
                        - Correct number of comments
                        - Correct number of likes
                        - Correct reference
                            - Correct publication author account address
                            - Correct publication index
                            - Correct publication type
            */
            let (author_account_address, publication_index) = {
                let publications = borrow_global<Publications>(liker_account_address);
                let likes = &publications.likes;
                assert!(
                    vector::length(likes) == 1,
                    0
                );

                let like = vector::borrow(likes, 0);
                assert!(
                    like.timestamp == timestamp::now_seconds(),
                    0
                );

                assert!(
                    like.reference.publication_author_account_address == author_account_address,
                    0
                );
                assert!(
                    like.reference.publication_index == 0,
                    0
                );
                assert!(
                    like.reference.publication_type == string::utf8(b"comment"),
                    0
                );

                (
                    like.reference.publication_author_account_address,
                    like.reference.publication_index
                )            };

            /* 
                - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let comments = &publications.comments;
                let comment = vector::borrow(comments, publication_index);
                let likes = &comment.likes;
                assert!(
                    vector::length(likes) == 1,
                    0
                );

                let actual_liker_account_username = vector::borrow(likes, 0);
                assert!(
                    actual_liker_account_username == &account_username_2,
                    0
                );
            };
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 2,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun like_test_success_multiple_likes_on_other_comment(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_3 = string::utf8(b"mind_slayer_3002");
        create_account(user1, account_username_3, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"myopinion.kahm");
        post(user1, account_username_1, post_content);

        let comment_content = string::utf8(b"mycomment.kahm");
        comment(
            user1, 
            account_username_1,
            comment_content,
            account_username_1,
            0
        );

        {
            like(
                user1, 
                account_username_2, 
                account_username_1, 
                string::utf8(b"comment"), 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let liker_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_2
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            /* 
                - Check the liker side
                    - Correct number of comments
                    - Correct comment
                        - Correct timestamp
                        - Correct id
                        - Correct content uri
                        - Correct number of comments
                        - Correct number of likes
                        - Correct reference
                            - Correct publication author account address
                            - Correct publication index
                            - Correct publication type
            */
            let (author_account_address, publication_index) = {
                let publications = borrow_global<Publications>(liker_account_address);
                let likes = &publications.likes;
                assert!(
                    vector::length(likes) == 1,
                    0
                );

                let like = vector::borrow(likes, 0);
                assert!(
                    like.timestamp == timestamp::now_seconds(),
                    0
                );

                assert!(
                    like.reference.publication_author_account_address == author_account_address,
                    0
                );
                assert!(
                    like.reference.publication_index == 0,
                    0
                );
                assert!(
                    like.reference.publication_type == string::utf8(b"comment"),
                    0
                );

                (
                    like.reference.publication_author_account_address,
                    like.reference.publication_index
                )
            };

            /*                 - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let comments = &publications.comments;
                let comment = vector::borrow(comments, publication_index);
                let likes = &comment.likes;
                assert!(
                    vector::length(likes) == 1,
                    0
                );

                let actual_liker_account_username = vector::borrow(likes, 0);
                assert!(
                    actual_liker_account_username == &account_username_2,
                    0
                );
            };
        };

        {
            like(
                user1, 
                account_username_3, 
                account_username_1, 
                string::utf8(b"comment"), 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let liker_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_3
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            /* 
                - Check the liker side
                    - Correct number of comments
                    - Correct comment
                        - Correct timestamp
                        - Correct id
                        - Correct content uri
                        - Correct number of comments
                        - Correct number of likes
                        - Correct reference
                            - Correct publication author account address
                            - Correct publication index
                            - Correct publication type
            */
            let (author_account_address, publication_index) = {
                let publications = borrow_global<Publications>(liker_account_address);
                let likes = &publications.likes;
                assert!(
                    vector::length(likes) == 1,
                    0
                );

                let like = vector::borrow(likes, 0);
                assert!(
                    like.timestamp == timestamp::now_seconds(),
                    0
                );

                assert!(
                    like.reference.publication_author_account_address == author_account_address,
                    0
                );
                assert!(
                    like.reference.publication_index == 0,
                    0
                );
                assert!(
                    like.reference.publication_type == string::utf8(b"comment"),
                    0
                );

                (
                    like.reference.publication_author_account_address,
                    like.reference.publication_index
                )
            };

            /* 
                - Check author side
            */ 
            {                let publications = borrow_global<Publications>(author_account_address);
                let comments = &publications.comments;
                let comment = vector::borrow(comments, publication_index);
                let likes = &comment.likes;
                assert!(
                    vector::length(likes) == 2,
                    0
                );

                let actual_liker_account_username = vector::borrow(likes, 1);
                assert!(
                    actual_liker_account_username == &account_username_3,
                    0
                );
            };
        };

        {
            like(
                user1, 
                account_username_1, 
                account_username_1, 
                string::utf8(b"comment"), 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let liker_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            /* 
                - Check the liker side
                    - Correct number of comments
                    - Correct comment
                        - Correct timestamp
                        - Correct id
                        - Correct content uri
                        - Correct number of comments
                        - Correct number of likes
                        - Correct reference
                            - Correct publication author account address
                            - Correct publication index
                            - Correct publication type
            */
            let (author_account_address, publication_index) = {
                let publications = borrow_global<Publications>(liker_account_address);
                let likes = &publications.likes;
                assert!(
                    vector::length(likes) == 1,
                    0
                );

                let like = vector::borrow(likes, 0);
                assert!(
                    like.timestamp == timestamp::now_seconds(),
                    0
                );

                assert!(
                    like.reference.publication_author_account_address == author_account_address,
                    0
                );
                assert!(
                    like.reference.publication_index == 0,
                    0
                );
                assert!(
                    like.reference.publication_type == string::utf8(b"comment"),
                    0
                );

                (
                    like.reference.publication_author_account_address,
                    like.reference.publication_index
                )
            };

            /* 
                - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let comments = &publications.comments;
                let comment = vector::borrow(comments, publication_index);                
                let likes = &comment.likes;
                assert!(
                    vector::length(likes) == 3,
                    0
                );

                let actual_liker_account_username = vector::borrow(likes, 2);
                assert!(
                    actual_liker_account_username == &account_username_1,
                    0
                );
            };
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 3,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 3,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );

        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun unlike_test_success_one_unlike_on_self_post(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"myopinion.kahm");
        post(user1, account_username_1, post_content);

        like(
            user1, 
            account_username_1, 
            account_username_1, 
            string::utf8(b"post"), 
            0
        );

        {
            unlike(
                user1, 
                account_username_1, 
                account_username_1, 
                string::utf8(b"post"), 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let liker_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            {
                let publications = borrow_global<Publications>(liker_account_address);
                let likes = &publications.likes;
                assert!(
                    vector::length(likes) == 0,
                    0
                );
            };

            /* 
                - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, 0);
                let likes = &post.likes;
                assert!(
                    vector::length(likes) == 0,
                    0
                );
            };
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 1,
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun unlike_test_success_one_unlike_on_other_post(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"myopinion.kahm");
        post(user1, account_username_1, post_content);

        like(
            user1, 
            account_username_2, 
            account_username_1, 
            string::utf8(b"post"), 
            0
        );

        {
            unlike(
                user1, 
                account_username_2, 
                account_username_1, 
                string::utf8(b"post"), 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let liker_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_2
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            /* 
                - Check the liker side
                    - Correct number of comments
                    - Correct comment
                        - Correct timestamp
                        - Correct id
                        - Correct content uri
                        - Correct number of comments
                        - Correct number of likes
                        - Correct reference
                            - Correct publication author account address
                            - Correct publication index
                            - Correct publication type
            */
            {
                let publications = borrow_global<Publications>(liker_account_address);
                let likes = &publications.likes;
                assert!(
                    vector::length(likes) == 0,
                    0
                );
            };

            /* 
                - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, 0);
                let likes = &post.likes;
                assert!(
                    vector::length(likes) == 0,
                    0
                );
            };        
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 2,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 1,
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun unlike_test_success_multiple_unlikes_on_other_post(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_3 = string::utf8(b"mind_slayer_3002");
        create_account(user1, account_username_3, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content = string::utf8(b"myopinion.kahm");
        post(user1, account_username_1, post_content);

        like(
            user1, 
            account_username_1, 
            account_username_1, 
            string::utf8(b"post"), 
            0
        );

        like(
            user1, 
            account_username_2, 
            account_username_1, 
            string::utf8(b"post"), 
            0
        );

        like(
            user1, 
            account_username_3,
            account_username_1,
            string::utf8(b"post"),
            0
        );

        {
            unlike(
                user1, 
                account_username_2, 
                account_username_1, 
                string::utf8(b"post"), 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let liker_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_2
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            {
                let publications = borrow_global<Publications>(liker_account_address);
                let likes = &publications.likes;
                assert!(
                    vector::length(likes) == 0,
                    0
                );
            };

            /* 
                - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, 0);
                let likes = &post.likes;
                assert!(
                    vector::length(likes) == 2,
                    0
                );
            };
        };

        {
            unlike(                
                user1, 
                account_username_1, 
                account_username_1, 
                string::utf8(b"post"), 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let liker_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            {
                let publications = borrow_global<Publications>(liker_account_address);
                let likes = &publications.likes;
                assert!(
                    vector::length(likes) == 0,
                    0
                );
            };

            /* 
                - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, 0);
                let likes = &post.likes;
                assert!(
                    vector::length(likes) == 1,
                    0
                );
            };
        };

        {
            unlike(
                user1, 
                account_username_3,
                account_username_1,
                string::utf8(b"post"), 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let liker_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_3
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            {
                let publications = borrow_global<Publications>(liker_account_address);
                let likes = &publications.likes;
                assert!(
                    vector::length(likes) == 0,
                    0
                );
            };

            /* 
                - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, 0);
                let likes = &post.likes;
                assert!(
                    vector::length(likes) == 0,
                    0
                );
            };
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 3,
                0
            );            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 3,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 3,
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun unlike_test_success_multiple_unlikes_on_other_comment(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_3 = string::utf8(b"mind_slayer_3002");
        create_account(user1, account_username_3, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content = string::utf8(b"myopinion.kahm");
        post(user1, account_username_1, post_content);

        let comment_content = string::utf8(b"mycomment.kahm");
        comment(
            user1, 
            account_username_1,
            comment_content,
            account_username_1,
            0
        );

        like(
            user1, 
            account_username_1, 
            account_username_1, 
            string::utf8(b"comment"), 
            0
        );

        like(
            user1, 
            account_username_2, 
            account_username_1, 
            string::utf8(b"comment"), 
            0
        );

        like(
            user1, 
            account_username_3,
            account_username_1,
            string::utf8(b"comment"),
            0
        );

        {
            unlike(
                user1, 
                account_username_2, 
                account_username_1, 
                string::utf8(b"comment"), 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let liker_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_2
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            {
                let publications = borrow_global<Publications>(liker_account_address);
                let likes = &publications.likes;
                assert!(
                    vector::length(likes) == 0,
                    0
                );
            };

            /* 
                - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let comments = &publications.comments;
                let comment = vector::borrow(comments, 0);
                let likes = &comment.likes;
                assert!(
                    vector::length(likes) == 2,
                    0
                );
            };
        };

        {
            unlike(
                user1, 
                account_username_1, 
                account_username_1, 
                string::utf8(b"comment"), 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");            let state = borrow_global<State>(expected_resource_account_address);

            let liker_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            {
                let publications = borrow_global<Publications>(liker_account_address);
                let likes = &publications.likes;
                assert!(
                    vector::length(likes) == 0,
                    0
                );
            };

            /* 
                - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let comments = &publications.comments;
                let comment = vector::borrow(comments, 0);
                let likes = &comment.likes;
                assert!(
                    vector::length(likes) == 1,
                    0
                );
            };
        };

        {
            unlike(
                user1, 
                account_username_3, 
                account_username_1, 
                string::utf8(b"comment"), 
                0
            );

            let expected_resource_account_address = account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);

            let liker_account_address = *table::borrow(                &state.account_registry.accounts,
                account_username_3
            );
            let author_account_address = *table::borrow(
                &state.account_registry.accounts,
                account_username_1
            );
            
            {
                let publications = borrow_global<Publications>(liker_account_address);
                let likes = &publications.likes;
                assert!(
                    vector::length(likes) == 0,
                    0
                );
            };

            /* 
                - Check author side
            */ 
            {
                let publications = borrow_global<Publications>(author_account_address);
                let comments = &publications.comments;
                let comment = vector::borrow(comments, 0);
                let likes = &comment.likes;
                assert!(
                    vector::length(likes) == 0,
                    0
                );
            };
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 3,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(                event::counter(&module_event_store.account_post_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 3,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 3,
                0
            );

        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun follow_test_success_follow_one_account(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        {
            follow(
                user1, 
                account_username_1, 
                account_username_2
            );

            let expected_resource_account_address = 
            account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);
            let account_registry = &state.account_registry;

            let follower_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_1
            );
            let followed_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_2
            );

            // Check followed account side
            {   
                let account_meta_data = borrow_global_mut<AccountMetaData>(followed_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;
                assert!(
                    vector::length(followers) == 1,
                    0
                );
                assert!(
                    vector::length(following) == 0,
                    0
                );

                let follower_account_address = vector::borrow(followers, 0);
                assert!(
                    follower_account_address == follower_account_address,
                    0
                );
            };

            // Check follower account side
            {
                let account_meta_data = borrow_global_mut<AccountMetaData>(follower_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;
                assert!(
                    vector::length(followers) == 0,
                    0
                );
                assert!(
                    vector::length(following) == 1,
                    0
                );

                let followed_account_address = vector::borrow(following, 0);
                assert!(
                    followed_account_address == followed_account_address,
                    0
                );
            };
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 2,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun follow_test_success_follow_multiple_accounts(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_3 = string::utf8(b"mind_slayer_3002");
        create_account(user1, account_username_3, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_4 = string::utf8(b"mind_slayer_3003");
        create_account(user1, account_username_4, string::utf8(b""), string::utf8(b""), vector[]);

        {
            follow(
                user1, 
                account_username_1, 
                account_username_2
            );

            let expected_resource_account_address = 
            account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);
            let account_registry = &state.account_registry;

            let follower_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_1
            );
            let followed_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_2
            );

            // Check followed account side
            {   
                let account_meta_data = borrow_global_mut<AccountMetaData>(followed_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;
                assert!(
                    vector::length(followers) == 1,
                    0
                );
                assert!(
                    vector::length(following) == 0,
                    0
                );

                let follower_account_address = vector::borrow(followers, 0);
                assert!(
                    follower_account_address == follower_account_address,
                    0
                );
            };

            // Check follower account side
            {
                let account_meta_data = borrow_global_mut<AccountMetaData>(follower_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;
                assert!(
                    vector::length(followers) == 0,
                    0
                );
                assert!(
                    vector::length(following) == 1,
                    0
                );

                let followed_account_address = vector::borrow(following, 0);
                assert!(
                    followed_account_address == followed_account_address,
                    0
                );
            };
        };

        {
            follow(
                user1, 
                account_username_1, 
                account_username_3
            );

            let expected_resource_account_address = 
            account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);
            let account_registry = &state.account_registry;

            let follower_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_1
            );
            let followed_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_3
            );

            // Check followed account side
            {   
                let account_meta_data = borrow_global_mut<AccountMetaData>(followed_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;
                assert!(
                    vector::length(followers) == 1,
                    0
                );
                assert!(
                    vector::length(following) == 0,
                    0
                );

                let follower_account_address = vector::borrow(followers, 0);
                assert!(
                    follower_account_address == follower_account_address,
                    0
                );
            };

            // Check follower account side
            {
                let account_meta_data = borrow_global_mut<AccountMetaData>(follower_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;
                assert!(
                    vector::length(followers) == 0,
                    0
                );
                assert!(
                    vector::length(following) == 2,
                    0
                );

                let followed_account_address = vector::borrow(following, 1);
                assert!(
                    followed_account_address == followed_account_address,
                    0
                );
            };
        };

        {
            follow(
                user1, 
                account_username_1, 
                account_username_4
            );

            let expected_resource_account_address = 
            account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);
            let account_registry = &state.account_registry;

            let follower_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_1
            );
            let followed_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_4
            );

            // Check followed account side
            {   
                let account_meta_data = borrow_global_mut<AccountMetaData>(followed_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;
                assert!(
                    vector::length(followers) == 1,
                    0
                );
                assert!(
                    vector::length(following) == 0,
                    0
                );

                let follower_account_address = vector::borrow(followers, 0);
                assert!(
                    follower_account_address == follower_account_address,
                    0
                );
            };

            // Check follower account side
            {
                let account_meta_data = borrow_global_mut<AccountMetaData>(follower_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;
                assert!(
                    vector::length(followers) == 0,
                    0
                );
                assert!(
                    vector::length(following) == 3,
                    0
                );

                let followed_account_address = vector::borrow(following, 1);
                assert!(
                    followed_account_address == followed_account_address,
                    0
                );
            };
        };
        
        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 4,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 3,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsernameNotRegistered, location = Self)]
    fun follow_test_failure_follower_does_not_exist(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        follow(
            user1, 
            account_username_1, 
            account_username_2
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsernameNotRegistered, location = Self)]
    fun follow_test_failure_following_does_not_exist(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");

        follow(
            user1, 
            account_username_1, 
            account_username_2
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EAccountDoesNotOwnUsername, location = Self)]
    fun follow_test_failure_account_does_not_username(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        follow(
            admin, 
            account_username_1, 
            account_username_2
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsersAreTheSame, location = Self)]
    fun follow_test_failure_self_follow(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        follow(
            user1, 
            account_username_1, 
            account_username_1
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUserFollowsUser, location = Self)]
    fun follow_test_failure_double_follow(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        follow(
            user1, 
            account_username_1, 
            account_username_2
        );
        follow(
            user1, 
            account_username_1, 
            account_username_2
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun create_account_test_success_follow_multiple_accounts(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_3 = string::utf8(b"mind_slayer_3002");
        create_account(user1, account_username_3, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_4 = string::utf8(b"mind_slayer_3003");
        create_account(user1, account_username_4, string::utf8(b""), string::utf8(b""), vector[]);

        {
            create_account(
                user1, 
                account_username_1, 
                string::utf8(b""), 
                string::utf8(b""),
                vector[
                    account_username_2,
                    account_username_4,
                    account_username_3
                ]
            );

            let expected_resource_account_address = 
            account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);
            let account_registry = &state.account_registry;

            let follower_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_1
            );
            let followed_account_address_2 = *table::borrow(
                &account_registry.accounts,
                account_username_2
            );
            let followed_account_address_4 = *table::borrow(
                &account_registry.accounts,
                account_username_4
            );
            let followed_account_address_3 = *table::borrow(
                &account_registry.accounts,
                account_username_3
            );

            // Check follower account side
            {   
                let account_meta_data = borrow_global_mut<AccountMetaData>(follower_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;
                assert!(
                    vector::length(followers) == 0,
                    0
                );
                assert!(
                    vector::length(following) == 3,
                    0
                );

                let follower_account_address = vector::borrow(following, 0);
                assert!(
                    follower_account_address == &account_username_2,
                    0
                );
                let follower_account_address = vector::borrow(following, 1);
                assert!(
                    follower_account_address == &account_username_4,
                    0
                );
                let follower_account_address = vector::borrow(following, 2);
                assert!(
                    follower_account_address == &account_username_3,
                    0
                );
            };

            // Check followed account side - followed_account_address_2
            {
                let account_meta_data = borrow_global_mut<AccountMetaData>(followed_account_address_2);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;
                assert!(
                    vector::length(followers) == 1,
                    0
                );
                assert!(
                    vector::length(following) == 0,
                    0
                );

                let followed_account_address = vector::borrow(followers, 0);
                assert!(
                    followed_account_address == &account_username_1,
                    0
                );
            };

            // Check followed account side - followed_account_address_4
            {
                let account_meta_data = borrow_global_mut<AccountMetaData>(followed_account_address_4);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;
                assert!(
                    vector::length(followers) == 1,
                    0
                );
                assert!(
                    vector::length(following) == 0,
                    0
                );

                let followed_account_address = vector::borrow(followers, 0);
                assert!(
                    followed_account_address == &account_username_1,
                    0
                );
            };
            

            // Check followed account side - followed_account_address_3
            {
                let account_meta_data = borrow_global_mut<AccountMetaData>(followed_account_address_3);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;
                assert!(
                    vector::length(followers) == 1,
                    0
                );
                assert!(
                    vector::length(following) == 0,
                    0
                );

                let followed_account_address = vector::borrow(followers, 0);
                assert!(
                    followed_account_address == &account_username_1,
                    0
                );
            };
        };
        
        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 4,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 3,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun unfollow_test_success_unfollow_one_account(
        admin:  &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]); 

        {
            follow(
                user1, 
                account_username_1, 
                account_username_2
            );

            let expected_resource_account_address = 
            account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);
            let account_registry = &state.account_registry;

            let follower_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_1
            );
            let followed_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_2
            );

            // Check followed account side
            {   
                let account_meta_data = borrow_global_mut<AccountMetaData>(followed_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;

                assert!(
                    vector::length(followers) == 1,
                    0
                );
                assert!(
                    vector::length(following) == 0,
                    0
                );

                let follower_account_address = vector::borrow(followers, 0);
                assert!(
                    follower_account_address == follower_account_address,
                    0
                );
            };

            // Check follower account side
            {
                let account_meta_data = borrow_global_mut<AccountMetaData>(follower_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;

                assert!(
                    vector::length(followers) == 0,
                    0
                );
                assert!(
                    vector::length(following) == 1,
                    0
                );

                let followed_account_address = vector::borrow(following, 0);
                assert!(
                    followed_account_address == followed_account_address,
                    0
                );
            };
        };

        {
            unfollow(
                user1, 
                account_username_1, 
                account_username_2
            );

            let expected_resource_account_address = 
            account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);
            let account_registry = &state.account_registry;

            let unfollower_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_1
            );
            let unfollowed_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_2
            );

            // Check unfollowed account side
            {   
                let account_meta_data = borrow_global_mut<AccountMetaData>(unfollowed_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;

                assert!(
                    vector::length(followers) == 0,
                    0
                );
                assert!(
                    vector::length(following) == 0,
                    0
                );
            };

            // Check unfollower account side
            {
                let account_meta_data = borrow_global_mut<AccountMetaData>(unfollower_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;

                assert!(
                    vector::length(followers) == 0,
                    0
                );
                assert!(
                    vector::length(following) == 0,
                    0
                );
            };
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 2,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 1,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun unfollow_test_success_unfollow_multiple_accounts(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_3 = string::utf8(b"mind_slayer_3002");
        create_account(user1, account_username_3, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_4 = string::utf8(b"mind_slayer_3003");
        create_account(user1, account_username_4, string::utf8(b""), string::utf8(b""), vector[]);

        {
            follow(
                user1, 
                account_username_1, 
                account_username_2
            );

            let expected_resource_account_address = 
            account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);
            let account_registry = &state.account_registry;

            let follower_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_1
            );
            let followed_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_2
            );

            // Check followed account side
            {   
                let account_meta_data = borrow_global_mut<AccountMetaData>(followed_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;
                assert!(
                    vector::length(followers) == 1,
                    0
                );
                assert!(
                    vector::length(following) == 0,
                    0
                );

                let follower_account_address = vector::borrow(followers, 0);
                assert!(
                    follower_account_address == follower_account_address,
                    0
                );
            };

            // Check follower account side
            {
                let account_meta_data = borrow_global_mut<AccountMetaData>(follower_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;
                assert!(
                    vector::length(followers) == 0,
                    0
                );
                assert!(
                    vector::length(following) == 1,
                    0
                );

                let followed_account_address = vector::borrow(following, 0);
                assert!(
                    followed_account_address == followed_account_address,
                    0
                );
            };
        };

        {
            follow(
                user1, 
                account_username_1, 
                account_username_3
            );

            let expected_resource_account_address = 
            account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);
            let account_registry = &state.account_registry;

            let follower_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_1
            );
            let followed_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_3
            );

            // Check followed account side
            {   
                let account_meta_data = borrow_global_mut<AccountMetaData>(followed_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;
                assert!(
                    vector::length(followers) == 1,
                    0
                );
                assert!(
                    vector::length(following) == 0,
                    0
                );
                let follower_account_address = vector::borrow(followers, 0);
                assert!(
                    follower_account_address == follower_account_address,
                    0
                );
            };

            // Check follower account side
            {
                let account_meta_data = borrow_global_mut<AccountMetaData>(follower_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;
                assert!(
                    vector::length(followers) == 0,
                    0
                );
                assert!(
                    vector::length(following) == 2,
                    0
                );

                let followed_account_address = vector::borrow(following, 1);
                assert!(
                    followed_account_address == followed_account_address,
                    0
                );
            };
        };

        {
            follow(
                user1, 
                account_username_1, 
                account_username_4
            );

            let expected_resource_account_address = 
            account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);
            let account_registry = &state.account_registry;

            let follower_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_1
            );
            let followed_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_4
            );

            // Check followed account side
            {   
                let account_meta_data = borrow_global_mut<AccountMetaData>(followed_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;
                assert!(
                    vector::length(followers) == 1,
                    0
                );
                assert!(
                    vector::length(following) == 0,
                    0
                );

                let follower_account_address = vector::borrow(followers, 0);
                assert!(
                    follower_account_address == follower_account_address,
                    0
                );
            };

            // Check follower account side
            {
                let account_meta_data = borrow_global_mut<AccountMetaData>(follower_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;
                assert!(
                    vector::length(followers) == 0,
                    0
                );
                assert!(
                    vector::length(following) == 3,
                    0
                );

                let followed_account_address = vector::borrow(following, 1);
                assert!(
                    followed_account_address == followed_account_address,
                    0
                );
            };
        };

        {
            unfollow(
                user1, 
                account_username_1, 
                account_username_3
            );

            let expected_resource_account_address = 
            account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);
            let account_registry = &state.account_registry;

            let unfollower_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_1
            );
            let unfollowed_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_3
            );

            // Check unfollowed account side
            {   
                let account_meta_data = borrow_global_mut<AccountMetaData>(unfollowed_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;

                assert!(
                    vector::length(followers) == 0,
                    0
                );
                assert!(
                    vector::length(following) == 0,
                    0
                );
            };

            // Check unfollower account side
            {
                let account_meta_data = borrow_global_mut<AccountMetaData>(unfollower_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;

                assert!(
                    vector::length(followers) == 0,
                    0
                );
                assert!(
                    vector::length(following) == 2,
                    0
                );
            };
        };

        {
            unfollow(
                user1, 
                account_username_1, 
                account_username_2
            );

            let expected_resource_account_address = 
            account::create_resource_address(&@overmind, b"decentralized platform");
            let state = borrow_global<State>(expected_resource_account_address);
            let account_registry = &state.account_registry;

            let unfollower_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_1
            );
            let unfollowed_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_2
            );

            // Check unfollowed account side
            {   
                let account_meta_data = borrow_global_mut<AccountMetaData>(unfollowed_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;

                assert!(
                    vector::length(followers) == 0,
                    0
                );
                assert!(
                    vector::length(following) == 0,
                    0
                );
            };

            // Check unfollower account side
            {
                let account_meta_data = borrow_global_mut<AccountMetaData>(unfollower_account_address);
                let followers = &account_meta_data.follower_account_usernames;
                let following = &account_meta_data.following_account_usernames;

                assert!(
                    vector::length(followers) == 0,
                    0
                );
                assert!(
                    vector::length(following) == 1,
                    0
                );
            };
        };

        {
            let module_event_store = 
                borrow_global_mut<ModuleEventStore>(account::create_resource_address(&@overmind, SEED));
            assert!(
                event::counter(&module_event_store.account_created_events) == 4,
                0
            );
            assert!(
                event::counter(&module_event_store.account_follow_events) == 3,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unfollow_events) == 2,
                0
            );
            assert!(
                event::counter(&module_event_store.account_post_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_comment_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_like_events) == 0,
                0
            );
            assert!(
                event::counter(&module_event_store.account_unlike_events) == 0,
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsernameAlreadyRegistered, location = Self)]
    fun create_account_test_failure_username_already_registered(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsernameNotRegistered, location = Self)]
    fun create_account_test_failure_follow_username_does_not_exist(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(
            user1, 
            account_username_1, 
            string::utf8(b""), 
            string::utf8(b""), 
            vector[account_username_2]
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUserFollowsUser, location = Self)]
    fun create_account_test_failure_follow_username_duplicate(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(
            user1, 
            account_username_1, 
            string::utf8(b""), 
            string::utf8(b""), 
            vector[account_username_2, account_username_2]
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsersAreTheSame, location = Self)]
    fun create_account_test_failure_follow_username_itself(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(
            user1, 
            account_username_1, 
            string::utf8(b""), 
            string::utf8(b""), 
            vector[account_username_2, account_username_1]
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EBioInvalidLength, location = Self)]
    fun update_bio_test_failure_bio_to_long(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let too_long_bio = string::utf8(b"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
        update_bio(user1, account_username_1, too_long_bio);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsernameNotRegistered, location = Self)]
    fun update_bio_test_failure_username_is_not_registered(
        admin: &signer, 
        user1: &signer
    ) acquires State, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");

        let bio = string::utf8(b"0");
        update_bio(user1, account_username_1, bio);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EAccountDoesNotOwnUsername, location = Self)]
    fun update_bio_test_failure_account_does_not_own_username(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let bio = string::utf8(b"0");
        update_bio(admin, account_username_1, bio);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsernameNotRegistered, location = Self)]
    fun update_profile_picture_test_failure_username_is_not_registered(
        admin: &signer, 
        user1: &signer
    ) acquires State, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");

        let bio = string::utf8(b"0");
        update_profile_picture(user1, account_username_1, bio);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EAccountDoesNotOwnUsername, location = Self)]
    fun update_profile_picture_test_failure_account_does_not_own_username(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let bio = string::utf8(b"0");
        update_profile_picture(admin, account_username_1, bio);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsernameNotRegistered, location = Self)]
    fun follower_test_failure_username_to_follow_is_not_registered(
        admin: &signer, 
        user1: &signer
    ) acquires State, AccountMetaData, ModuleEventStore {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");

        follow(user1, account_username_1, account_username_2);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsernameNotRegistered, location = Self)]
    fun follower_test_failure_follower_username_is_not_registered(
        admin: &signer, 
        user1: &signer
    ) acquires State, AccountMetaData, ModuleEventStore {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");

        follow(user1, account_username_2, account_username_1);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EAccountDoesNotOwnUsername, location = Self)]
    fun follower_test_failure_account_does_own_follower_username(
        admin: &signer, 
        user1: &signer
    ) acquires State, AccountMetaData, ModuleEventStore {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        follow(admin, account_username_2, account_username_1);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsersAreTheSame, location = Self)]
    fun follower_test_failure_same_usernames(
        admin: &signer, 
        user1: &signer
    ) acquires State, AccountMetaData, ModuleEventStore {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        follow(user1, account_username_1, account_username_1);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUserFollowsUser, location = Self)]
    fun follower_test_failure_follow_twice(
        admin: &signer, 
        user1: &signer
    ) acquires State, AccountMetaData, ModuleEventStore {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        follow(user1, account_username_2, account_username_1);

        follow(user1, account_username_2, account_username_1);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsernameNotRegistered, location = Self)]
    fun unfollow_failure_username_to_follow_is_not_registered(
        admin: &signer, 
        user1: &signer
    ) acquires State, AccountMetaData, ModuleEventStore {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");

        unfollow(user1, account_username_1, account_username_2);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsernameNotRegistered, location = Self)]
    fun unfollow_failure_follower_username_is_not_registered(
        admin: &signer, 
        user1: &signer
    ) acquires State, AccountMetaData, ModuleEventStore {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");

        unfollow(user1, account_username_2, account_username_1);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EAccountDoesNotOwnUsername, location = Self)]
    fun unfollow_failure_account_does_own_follower_username(
        admin: &signer, 
        user1: &signer
    ) acquires State, AccountMetaData, ModuleEventStore {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        follow(user1, account_username_2, account_username_1);

        unfollow(admin, account_username_2, account_username_1)
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsersAreTheSame, location = Self)]
    fun unfollow_failure_same_usernames(
        admin: &signer, 
        user1: &signer
    ) acquires State, AccountMetaData, ModuleEventStore {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        follow(user1, account_username_2, account_username_1);

        unfollow(user1, account_username_2, account_username_2);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUserDoesNotFollowUser, location = Self)]
    fun unfollow_failure_follow_twice(
        admin: &signer, 
        user1: &signer
    ) acquires State, AccountMetaData, ModuleEventStore {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        follow(user1, account_username_2, account_username_1);

        unfollow(user1, account_username_2, account_username_1);
        unfollow(user1, account_username_2, account_username_1);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsernameNotRegistered, location = Self)]
    fun post_test_failure_username_is_not_registered(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");

        let post_content = string::utf8(b"0");
        post(user1, account_username_1, post_content);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EAccountDoesNotOwnUsername, location = Self)]
    fun post_test_failure_account_does_not_own_username(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"0");
        post(admin, account_username_1, post_content);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EContentInvalidLength, location = Self)]
    fun post_test_failure_too_long(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
        post(admin, account_username_1, post_content);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsernameNotRegistered, location = Self)]
    fun comment_test_failure_author_username_is_not_registered(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");

        let post_content = string::utf8(b"0");
        post(user1, account_username_1, post_content);

        let comment_content = string::utf8(b"0");
        comment(user1, account_username_1, comment_content, account_username_2, 0);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsernameNotRegistered, location = Self)]
    fun comment_test_failure_commenter_username_is_not_registered(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");

        let post_content = string::utf8(b"0");
        post(user1, account_username_1, post_content);

        let comment_content = string::utf8(b"0");
        comment(user1, account_username_2, comment_content, account_username_1, 0);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EAccountDoesNotOwnUsername, location = Self)]
    fun comment_test_failure_account_does_not_own_username(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"0");
        post(user1, account_username_1, post_content);

        let comment_content = string::utf8(b"0");
        comment(admin, account_username_1, comment_content, account_username_1, 0);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EPublicationDoesNotExistForUser, location = Self)]
    fun comment_test_failure_publication_does_not_exist_1(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"0");
        post(user1, account_username_1, post_content);

        let comment_content = string::utf8(b"0");
        comment(user1, account_username_1, comment_content, account_username_1, 1);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EPublicationDoesNotExistForUser, location = Self)]
    fun comment_test_failure_publication_does_not_exist_2(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"0");
        post(user1, account_username_1, post_content);
        
        let comment_content = string::utf8(b"0");
        comment(user1, account_username_1, comment_content, account_username_1, 0);

        let comment_content = string::utf8(b"0");
        comment(user1, account_username_1, comment_content, account_username_1, 0);

        let comment_content = string::utf8(b"0");
        comment(user1, account_username_1, comment_content, account_username_2, 0);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EPublicationTypeToLikeIsInvalid, location = Self)]
    fun like_test_failure_invalid_publication_type_1(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"0");
        post(user1, account_username_1, post_content);

        like(user1, account_username_1, account_username_2, string::utf8(b"like"), 0);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EPublicationTypeToLikeIsInvalid, location = Self)]
    fun like_test_failure_invalid_publication_type_2(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"0");
        post(user1, account_username_1, post_content);

        like(user1, account_username_1, account_username_2, string::utf8(b"share"), 0);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsernameNotRegistered, location = Self)]
    fun like_test_failure_author_username_is_not_registered(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");

        let post_content = string::utf8(b"0");
        post(user1, account_username_1, post_content);

        like(user1, account_username_1, account_username_2, string::utf8(b"post"), 0);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsernameNotRegistered, location = Self)]
    fun like_test_failure_liker_username_is_not_registered(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"0");
        post(user1, account_username_1, post_content);

        like(user1, account_username_1, account_username_2, string::utf8(b"post"), 0);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EAccountDoesNotOwnUsername, location = Self)]
    fun like_test_failure_account_does_not_own_username(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"0");
        post(user1, account_username_1, post_content);

        like(admin, account_username_1, account_username_2, string::utf8(b"post"), 0);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EPublicationDoesNotExistForUser, location = Self)]
    fun like_test_failure_publication_does_not_exist(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"0");
        post(user1, account_username_1, post_content);

        like(user1, account_username_1, account_username_2, string::utf8(b"comment"), 0);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUserHasLikedPublication, location = Self)]
    fun like_test_failure_already_liked(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"0");
        post(user1, account_username_2, post_content);

        like(user1, account_username_1, account_username_2, string::utf8(b"post"), 0);
        like(user1, account_username_1, account_username_2, string::utf8(b"post"), 0);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EPublicationTypeToLikeIsInvalid, location = Self)]
    fun unlike_test_failure_invalid_publication_type_1(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"0");
        post(user1, account_username_1, post_content);

        unlike(user1, account_username_1, account_username_2, string::utf8(b"like"), 0);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EPublicationTypeToLikeIsInvalid, location = Self)]
    fun unlike_test_failure_invalid_publication_type_2(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"0");
        post(user1, account_username_1, post_content);

        unlike(user1, account_username_1, account_username_2, string::utf8(b"share"), 0);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsernameNotRegistered, location = Self)]
    fun unlike_test_failure_author_username_is_not_registered(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");

        let post_content = string::utf8(b"0");
        post(user1, account_username_1, post_content);

        unlike(user1, account_username_1, account_username_2, string::utf8(b"post"), 0);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUsernameNotRegistered, location = Self)]
    fun unlike_test_failure_liker_username_is_not_registered(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"0");
        post(user1, account_username_1, post_content);

        unlike(user1, account_username_1, account_username_2, string::utf8(b"post"), 0);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EAccountDoesNotOwnUsername, location = Self)]
    fun unlike_test_failure_account_does_not_own_username(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"0");
        post(user1, account_username_1, post_content);

        unlike(admin, account_username_1, account_username_2, string::utf8(b"post"), 0);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EPublicationDoesNotExistForUser, location = Self)]
    fun unlike_test_failure_publication_does_not_exist(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"0");
        post(user1, account_username_1, post_content);

        unlike(user1, account_username_1, account_username_2, string::utf8(b"comment"), 0);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUserHasNotLikedPublication, location = Self)]
    fun unlike_test_failure_not_liked(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"0");
        post(user1, account_username_2, post_content);

        unlike(user1, account_username_1, account_username_2, string::utf8(b"post"), 0);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure(abort_code = EUserHasNotLikedPublication, location = Self)]
    fun unlike_test_failure_already_unliked(
        admin: &signer, 
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address_1 = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address_1);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content = string::utf8(b"0");
        post(user1, account_username_2, post_content);

        like(user1, account_username_1, account_username_2, string::utf8(b"post"), 0);

        unlike(user1, account_username_1, account_username_2, string::utf8(b"post"), 0);
        unlike(user1, account_username_1, account_username_2, string::utf8(b"post"), 0);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_global_timeline_test_empty_timeline(
        admin: &signer,
        user1: &signer
    ) acquires Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let (accounts, posts, liked) = get_global_timeline(string::utf8(b""), 10, 0);
        assert!(
            vector::length(&accounts) == 0,
            0
        );
        assert!(
            vector::length(&posts) == 0,
            1
        );
        assert!(
            vector::length(&liked) == 0,
            2
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_global_timeline_test_partial_first_page(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content_1 = string::utf8(b"0");
        let post_content_2 = string::utf8(b"1");
        let post_content_3 = string::utf8(b"2");
        let post_content_4 = string::utf8(b"3");
        let post_content_5 = string::utf8(b"4");

        post(user1, account_username_1, post_content_1);
        post(user1, account_username_1, post_content_2);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_1, post_content_5);

        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 4);

        let (
            timeline_authors, 
            timeline_posts, 
            timeline_likes
        ) = get_global_timeline(account_username_2, 10, 0);
        assert!(
            vector::length(&timeline_authors) == 5,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 5,
            1
        );
        assert!(
            vector::length(&timeline_likes) == 5,
            2
        );

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_1 = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 0);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 4);
            let timeline_post = vector::borrow(&timeline_posts, 0);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 0);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 1);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 3);
            let timeline_post = vector::borrow(&timeline_posts, 1);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 1);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 2);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 2);
            let timeline_post = vector::borrow(&timeline_posts, 2);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 2);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 3);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 1);
            let timeline_post = vector::borrow(&timeline_posts, 3);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 3);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 4);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 0);
            let timeline_post = vector::borrow(&timeline_posts, 4);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 4);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_global_timeline_test_full_first_page(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content_1 = string::utf8(b"0");
        let post_content_2 = string::utf8(b"1");
        let post_content_3 = string::utf8(b"2");
        let post_content_4 = string::utf8(b"3");
        let post_content_5 = string::utf8(b"4");

        post(user1, account_username_1, post_content_1);
        post(user1, account_username_1, post_content_2);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_1, post_content_5);

        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 4);

        let (
            timeline_authors, 
            timeline_posts, 
            timeline_likes
        ) = get_global_timeline(account_username_2, 3, 0);
        assert!(
            vector::length(&timeline_authors) == 3,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 3,
            1
        );
        assert!(
            vector::length(&timeline_likes) == 3,
            2
        );

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_1 = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 0);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 4);
            let timeline_post = vector::borrow(&timeline_posts, 0);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 0);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 1);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 3);
            let timeline_post = vector::borrow(&timeline_posts, 1);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 1);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 2);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 2);
            let timeline_post = vector::borrow(&timeline_posts, 2);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 2);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_global_timeline_test_full_second_page(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content_1 = string::utf8(b"0");
        let post_content_2 = string::utf8(b"1");
        let post_content_3 = string::utf8(b"2");
        let post_content_4 = string::utf8(b"3");
        let post_content_5 = string::utf8(b"4");

        post(user1, account_username_1, post_content_1);
        post(user1, account_username_1, post_content_2);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_1, post_content_5);

        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 4);

        let (
            timeline_authors, 
            timeline_posts, 
            timeline_likes
        ) = get_global_timeline(account_username_2, 2, 1);
        assert!(
            vector::length(&timeline_authors) == 2,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 2,
            1
        );
        assert!(
            vector::length(&timeline_likes) == 2,
            2
        );

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_1 = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 0);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 2);
            let timeline_post = vector::borrow(&timeline_posts, 0);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 0);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 1);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 1);
            let timeline_post = vector::borrow(&timeline_posts, 1);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 1);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_global_timeline_test_partial_third_page(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content_1 = string::utf8(b"0");
        let post_content_2 = string::utf8(b"1");
        let post_content_3 = string::utf8(b"2");
        let post_content_4 = string::utf8(b"3");
        let post_content_5 = string::utf8(b"4");

        post(user1, account_username_1, post_content_1);
        post(user1, account_username_1, post_content_2);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_1, post_content_5);

        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 4);

        let (
            timeline_authors, 
            timeline_posts, 
            timeline_likes
        ) = get_global_timeline(account_username_2, 2, 2);
        assert!(
            vector::length(&timeline_authors) == 1,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 1,
            1
        );
        assert!(
            vector::length(&timeline_likes) == 1,
            2
        );

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_1 = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 0);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 0);
            let timeline_post = vector::borrow(&timeline_posts, 0);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 0);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_global_timeline_test_empty_fourth_page(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content_1 = string::utf8(b"0");
        let post_content_2 = string::utf8(b"1");
        let post_content_3 = string::utf8(b"2");
        let post_content_4 = string::utf8(b"3");
        let post_content_5 = string::utf8(b"4");

        post(user1, account_username_1, post_content_1);
        post(user1, account_username_1, post_content_2);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_1, post_content_5);

        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 4);

        let (
            timeline_authors, 
            timeline_posts, 
            timeline_likes
        ) = get_global_timeline(account_username_2, 2, 3);
        assert!(
            vector::length(&timeline_authors) == 0,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 0,
            1
        );
        assert!(
            vector::length(&timeline_likes) == 0,
            2
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_following_timeline_test_no_registered_username(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        // create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        // let post_content_1 = string::utf8(b"0");
        // let post_content_2 = string::utf8(b"1");
        // let post_content_3 = string::utf8(b"2");
        // let post_content_4 = string::utf8(b"3");
        // let post_content_5 = string::utf8(b"4");

        // post(user1, account_username_1, post_content_1);
        // post(user1, account_username_1, post_content_2);
        // post(user1, account_username_1, post_content_3);
        // post(user1, account_username_1, post_content_4);
        // post(user1, account_username_1, post_content_5);

        // like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        // like(user1, account_username_2, account_username_1, string::utf8(b"post"), 4);

        let (accounts, posts, liked) = 
            get_following_timeline(account_username_2, account_username_1, 10, 0);
        assert!(
            vector::length(&accounts) == 0,
            0
        );
        assert!(
            vector::length(&posts) == 0,
            1
        );
        assert!(
            vector::length(&liked) == 0,
            2
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_following_timeline_test_empty_timeline(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let post_content_1 = string::utf8(b"0");
        let post_content_2 = string::utf8(b"1");
        let post_content_3 = string::utf8(b"2");
        let post_content_4 = string::utf8(b"3");
        let post_content_5 = string::utf8(b"4");

        post(user1, account_username_1, post_content_1);
        post(user1, account_username_1, post_content_2);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_1, post_content_5);

        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 4);

        let (accounts, posts, liked) = 
            get_following_timeline(account_username_2, account_username_1, 10, 0);
        assert!(
            vector::length(&accounts) == 0,
            0
        );
        assert!(
            vector::length(&posts) == 0,
            1
        );
        assert!(
            vector::length(&liked) == 0,
            2
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_following_timeline_test_partial_first_page(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content_1 = string::utf8(b"0");
        let post_content_2 = string::utf8(b"1");
        let post_content_3 = string::utf8(b"2");
        let post_content_4 = string::utf8(b"3");
        let post_content_5 = string::utf8(b"4");

        post(user1, account_username_1, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_1, post_content_2);
        post(user1, account_username_2, post_content_2);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_1, post_content_5);

        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 4);

        follow(user1, account_username_2, account_username_1);

        let (
            timeline_authors, 
            timeline_posts, 
            timeline_likes
        ) = get_following_timeline(account_username_2, account_username_2, 10, 0);
        assert!(
            vector::length(&timeline_authors) == 5,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 5,
            1
        );
        assert!(
            vector::length(&timeline_likes) == 5,
            2
        );

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_1 = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 0);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 4);
            let timeline_post = vector::borrow(&timeline_posts, 0);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 0);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 1);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 3);
            let timeline_post = vector::borrow(&timeline_posts, 1);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 1);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 2);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 2);
            let timeline_post = vector::borrow(&timeline_posts, 2);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 2);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 3);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 1);
            let timeline_post = vector::borrow(&timeline_posts, 3);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 3);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 4);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 0);
            let timeline_post = vector::borrow(&timeline_posts, 4);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 4);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_following_timeline_test_full_first_page(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content_1 = string::utf8(b"0");
        let post_content_2 = string::utf8(b"1");
        let post_content_3 = string::utf8(b"2");
        let post_content_4 = string::utf8(b"3");
        let post_content_5 = string::utf8(b"4");

        post(user1, account_username_1, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_1, post_content_2);
        post(user1, account_username_2, post_content_2);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_1, post_content_5);

        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 4);

        follow(user1, account_username_2, account_username_1);

        let (
            timeline_authors, 
            timeline_posts, 
            timeline_likes
        ) = get_following_timeline(account_username_2, account_username_2, 3, 0);
        assert!(
            vector::length(&timeline_authors) == 3,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 3,
            1
        );
        assert!(
            vector::length(&timeline_likes) == 3,
            2
        );

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_1 = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 0);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 4);
            let timeline_post = vector::borrow(&timeline_posts, 0);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 0);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 1);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 3);
            let timeline_post = vector::borrow(&timeline_posts, 1);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 1);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 2);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 2);
            let timeline_post = vector::borrow(&timeline_posts, 2);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 2);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_following_timeline_test_full_second_page(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content_1 = string::utf8(b"0");
        let post_content_2 = string::utf8(b"1");
        let post_content_3 = string::utf8(b"2");
        let post_content_4 = string::utf8(b"3");
        let post_content_5 = string::utf8(b"4");

        post(user1, account_username_1, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_1, post_content_2);
        post(user1, account_username_2, post_content_2);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_1, post_content_5);

        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 4);

        follow(user1, account_username_2, account_username_1);

        let (
            timeline_authors, 
            timeline_posts, 
            timeline_likes
        ) = get_following_timeline(account_username_2, account_username_2, 2, 1);
        assert!(
            vector::length(&timeline_authors) == 2,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 2,
            1
        );
        assert!(
            vector::length(&timeline_likes) == 2,
            2
        );

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_1 = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 0);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 2);
            let timeline_post = vector::borrow(&timeline_posts, 0);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 0);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 1);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 1);
            let timeline_post = vector::borrow(&timeline_posts, 1);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 1);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_following_timeline_test_partial_third_page(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content_1 = string::utf8(b"0");
        let post_content_2 = string::utf8(b"1");
        let post_content_3 = string::utf8(b"2");
        let post_content_4 = string::utf8(b"3");
        let post_content_5 = string::utf8(b"4");

        post(user1, account_username_1, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_1, post_content_2);
        post(user1, account_username_2, post_content_2);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_1, post_content_5);

        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 4);

        follow(user1, account_username_2, account_username_1);

        let (
            timeline_authors, 
            timeline_posts, 
            timeline_likes
        ) = get_following_timeline(account_username_2, account_username_2, 2, 2);
        assert!(
            vector::length(&timeline_authors) == 1,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 1,
            1
        );
        assert!(
            vector::length(&timeline_likes) == 1,
            2
        );

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_1 = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );

        {
            let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
            let timeline_account = vector::borrow(&timeline_authors, 0);
            assert!(
                timeline_account == account_meta_data,
                0
            );

            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 0);
            let timeline_post = vector::borrow(&timeline_posts, 0);
            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 0);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_following_timeline_test_empty_fourth_page(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content_1 = string::utf8(b"0");
        let post_content_2 = string::utf8(b"1");
        let post_content_3 = string::utf8(b"2");
        let post_content_4 = string::utf8(b"3");
        let post_content_5 = string::utf8(b"4");

        post(user1, account_username_1, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_1, post_content_2);
        post(user1, account_username_2, post_content_2);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_1, post_content_5);

        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 4);

        follow(user1, account_username_2, account_username_1);

        let (
            timeline_authors, 
            timeline_posts, 
            timeline_likes
        ) = get_following_timeline(account_username_2, account_username_2, 2, 3);
        assert!(
            vector::length(&timeline_authors) == 0,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 0,
            1
        );
        assert!(
            vector::length(&timeline_likes) == 0,
            2
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_posts_test_no_registered_account(
        admin: &signer,
        user1: &signer
    ) acquires State, Publications, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        // create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        // create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        // let post_content_1 = string::utf8(b"0");
        // let post_content_2 = string::utf8(b"1");
        // // let post_content_3 = string::utf8(b"2");
        // // let post_content_4 = string::utf8(b"3");
        // let post_content_5 = string::utf8(b"4");

        // // post(user1, account_username_1, post_content_1);
        // post(user1, account_username_2, post_content_1);
        // post(user1, account_username_2, post_content_1);
        // // post(user1, account_username_1, post_content_2);
        // post(user1, account_username_2, post_content_2);
        // // post(user1, account_username_1, post_content_3);
        // // post(user1, account_username_1, post_content_4);
        // post(user1, account_username_2, post_content_5);
        // post(user1, account_username_2, post_content_5);
        // post(user1, account_username_2, post_content_5);
        // // post(user1, account_username_1, post_content_5);

        // // like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        // // like(user1, account_username_2, account_username_1, string::utf8(b"post"), 4);

        // follow(user1, account_username_2, account_username_1);

        let (
            author_account, 
            timeline_posts, 
            timeline_likes
        ) = get_account_posts(account_username_1, account_username_2, 10, 0);

        let account_meta_data = AccountMetaData {
            creation_timestamp: 0,
            account_address: @0x0, 
            username: string::utf8(b""),
            name: string::utf8(b""),
            profile_picture_uri: string::utf8(b""),
            bio: string::utf8(b""),
            follower_account_usernames: vector[],
            following_account_usernames: vector[]
        };
        assert!(
            author_account == account_meta_data,
            0
        );

        assert!(
            vector::length(&timeline_posts) == 0,
            0
        );
        assert!(
            vector::length(&timeline_likes) == 0,
            1
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_posts_test_empty_first_page(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content_1 = string::utf8(b"0");
        let post_content_2 = string::utf8(b"1");
        // let post_content_3 = string::utf8(b"2");
        // let post_content_4 = string::utf8(b"3");
        let post_content_5 = string::utf8(b"4");

        // post(user1, account_username_1, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_2, post_content_1);
        // post(user1, account_username_1, post_content_2);
        post(user1, account_username_2, post_content_2);
        // post(user1, account_username_1, post_content_3);
        // post(user1, account_username_1, post_content_4);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        // post(user1, account_username_1, post_content_5);

        // like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        // like(user1, account_username_2, account_username_1, string::utf8(b"post"), 4);

        follow(user1, account_username_2, account_username_1);

        let (
            author_account, 
            timeline_posts, 
            timeline_likes
        ) = get_account_posts(account_username_1, account_username_2, 10, 0);

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_1 = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
        assert!(
            &author_account == account_meta_data,
            0
        );

        assert!(
            vector::length(&timeline_posts) == 0,
            0
        );
        assert!(
            vector::length(&timeline_likes) == 0,
            1
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_posts_test_partial_first_page(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content_1 = string::utf8(b"0");
        let post_content_2 = string::utf8(b"1");
        let post_content_3 = string::utf8(b"2");
        let post_content_4 = string::utf8(b"3");
        let post_content_5 = string::utf8(b"4");

        post(user1, account_username_1, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_1, post_content_2);
        post(user1, account_username_2, post_content_2);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_1, post_content_5);

        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 4);

        follow(user1, account_username_2, account_username_1);

        let (
            author_account, 
            timeline_posts, 
            timeline_likes
        ) = get_account_posts(account_username_1, account_username_2, 10, 0);

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_1 = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
        assert!(
            &author_account == account_meta_data,
            0
        );

        assert!(
            vector::length(&timeline_posts) == 5,
            0
        );
        assert!(
            vector::length(&timeline_likes) == 5,
            0
        );

        {
            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 4);

            let timeline_post = vector::borrow(&timeline_posts, 0);

            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 0);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

        {
            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 3);

            let timeline_post = vector::borrow(&timeline_posts, 1);

            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 1);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

        {
            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 2);

            let timeline_post = vector::borrow(&timeline_posts, 2);

            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 2);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

        {
            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 1);

            let timeline_post = vector::borrow(&timeline_posts, 3);

            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 3);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

        {
            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 0);

            let timeline_post = vector::borrow(&timeline_posts, 4);

            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 4);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };
        
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_posts_test_full_first_page(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content_1 = string::utf8(b"0");
        let post_content_2 = string::utf8(b"1");
        let post_content_3 = string::utf8(b"2");
        let post_content_4 = string::utf8(b"3");
        let post_content_5 = string::utf8(b"4");

        post(user1, account_username_1, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_1, post_content_2);
        post(user1, account_username_2, post_content_2);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_1, post_content_5);

        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 4);

        follow(user1, account_username_2, account_username_1);

        let (
            author_account, 
            timeline_posts, 
            timeline_likes
        ) = get_account_posts(account_username_1, account_username_2, 2, 0);

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_1 = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
        assert!(
            &author_account == account_meta_data,
            0
        );

        assert!(
            vector::length(&timeline_posts) == 2,
            0
        );
        assert!(
            vector::length(&timeline_likes) == 2,
            0
        );

        {
            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 4);

            let timeline_post = vector::borrow(&timeline_posts, 0);

            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 0);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

        {
            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 3);

            let timeline_post = vector::borrow(&timeline_posts, 1);

            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 1);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_posts_test_full_second_page(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content_1 = string::utf8(b"0");
        let post_content_2 = string::utf8(b"1");
        let post_content_3 = string::utf8(b"2");
        let post_content_4 = string::utf8(b"3");
        let post_content_5 = string::utf8(b"4");

        post(user1, account_username_1, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_1, post_content_2);
        post(user1, account_username_2, post_content_2);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_1, post_content_5);

        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 4);

        follow(user1, account_username_2, account_username_1);

        let (
            author_account, 
            timeline_posts, 
            timeline_likes
        ) = get_account_posts(account_username_1, account_username_2, 2, 1);

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_1 = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
        assert!(
            &author_account == account_meta_data,
            0
        );

        assert!(
            vector::length(&timeline_posts) == 2,
            0
        );
        assert!(
            vector::length(&timeline_likes) == 2,
            0
        );

        {
            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 2);

            let timeline_post = vector::borrow(&timeline_posts, 0);

            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 0);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };

        {
            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 1);

            let timeline_post = vector::borrow(&timeline_posts, 1);

            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 1);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };
        
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_posts_test_partial_third_page(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content_1 = string::utf8(b"0");
        let post_content_2 = string::utf8(b"1");
        let post_content_3 = string::utf8(b"2");
        let post_content_4 = string::utf8(b"3");
        let post_content_5 = string::utf8(b"4");

        post(user1, account_username_1, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_1, post_content_2);
        post(user1, account_username_2, post_content_2);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_1, post_content_5);

        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 4);

        follow(user1, account_username_2, account_username_1);

        let (
            author_account, 
            timeline_posts, 
            timeline_likes
        ) = get_account_posts(account_username_1, account_username_2, 2, 2);

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_1 = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
        assert!(
            &author_account == account_meta_data,
            0
        );

        assert!(
            vector::length(&timeline_posts) == 1,
            0
        );
        assert!(
            vector::length(&timeline_likes) == 1,
            0
        );

        {
            let publications = borrow_global<Publications>(account_address_1);
            let posts = &publications.posts;
            let post = vector::borrow(posts, 0);

            let timeline_post = vector::borrow(&timeline_posts, 0);

            assert!(
                post == timeline_post,
                0
            );

            let accounts_that_liked = &post.likes;
            let timeline_liked = vector::borrow(&timeline_likes, 0);
            assert!(
                timeline_liked == &vector::contains(accounts_that_liked, &account_username_2),
                0
            );
        };
        
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_posts_test_empty_fourth_page(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content_1 = string::utf8(b"0");
        let post_content_2 = string::utf8(b"1");
        let post_content_3 = string::utf8(b"2");
        let post_content_4 = string::utf8(b"3");
        let post_content_5 = string::utf8(b"4");

        post(user1, account_username_1, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_1, post_content_2);
        post(user1, account_username_2, post_content_2);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_1, post_content_5);

        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 4);

        follow(user1, account_username_2, account_username_1);

        let (
            author_account, 
            timeline_posts, 
            timeline_likes
        ) = get_account_posts(account_username_1, account_username_2, 2, 3);

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_1 = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
        assert!(
            &author_account == account_meta_data,
            0
        );

        assert!(
            vector::length(&timeline_posts) == 0,
            0
        );
        assert!(
            vector::length(&timeline_likes) == 0,
            0
        );
        
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_followers_test_not_registered_username(
        admin: &signer, 
        user1: &signer
    ) acquires State, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username = string::utf8(b"mind_slayer_3000");

       let (account, follower_accounts) = get_account_followers(
            account_username,
            20,
            0
        );

        let account_meta_data = AccountMetaData {
            creation_timestamp: 0,
            account_address: @0x0, 
            username: string::utf8(b""),
            name: string::utf8(b""),
            profile_picture_uri: string::utf8(b""),
            bio: string::utf8(b""),
            follower_account_usernames: vector[],
            following_account_usernames: vector[]
        };
        assert!(
            account == account_meta_data,
            0
        );

        assert!(
            vector::length(&follower_accounts) == 0,
            0
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_followers_test_no_followers(
        admin: &signer,
        user1: &signer
    ) acquires State, AccountMetaData, ModuleEventStore {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username, string::utf8(b""), string::utf8(b""), vector[]);

        let (account, follower_accounts) = get_account_followers(
            account_username,
            20,
            0
        );
         
        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address = *table::borrow(
            &account_registry.accounts,
            account_username
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address);
        assert!(
            &account == account_meta_data,
            0
        );

        assert!(
            vector::length(&follower_accounts) == 0,
            0
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_followers_test_partial_first_page(
        admin: &signer, 
        user1: &signer
    ) acquires State, AccountMetaData, ModuleEventStore {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        follow(user1, account_username_2, account_username_1);

        let (account, follower_accounts) = get_account_followers(
            account_username_1,
            2,
            0
        );

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address);
        assert!(
            &account == account_meta_data,
            0
        );

        assert!(
            vector::length(&follower_accounts) == 1,
            0
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_followers_test_full_first_page(
        admin: &signer,
        user1: &signer
    ) acquires State, AccountMetaData, ModuleEventStore {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_3 = string::utf8(b"mind_slayer_3002");
        create_account(user1, account_username_3, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_4 = string::utf8(b"mind_slayer_3003");
        create_account(user1, account_username_4, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_5 = string::utf8(b"mind_slayer_3004");
        create_account(user1, account_username_5, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_6 = string::utf8(b"mind_slayer_3005");
        create_account(user1, account_username_6, string::utf8(b""), string::utf8(b""), vector[]);

        follow(user1, account_username_2, account_username_1);
        follow(user1, account_username_3, account_username_1);
        follow(user1, account_username_4, account_username_1);
        follow(user1, account_username_5, account_username_1);
        follow(user1, account_username_6, account_username_1);

        let (account, follower_accounts) = get_account_followers(
            account_username_1,
            2,
            0
        );
        
        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address);
        assert!(
            &account == account_meta_data,
            0
        );

        assert!(
            vector::length(&follower_accounts) == 2,
            0
        );

        {
            let follower_account = vector::borrow(&follower_accounts, 0);

            let follower_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_6
            );
            let follower_account_meta_data = borrow_global<AccountMetaData>(follower_account_address);

            assert!(
                follower_account == follower_account_meta_data,
                0
            );
        };

        {
            let follower_account = vector::borrow(&follower_accounts, 1);

            let follower_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_5
            );
            let follower_account_meta_data = borrow_global<AccountMetaData>(follower_account_address);

            assert!(
                follower_account == follower_account_meta_data,
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_followers_test_partial_third_page(
        admin: &signer,
        user1: &signer
    ) acquires State, AccountMetaData, ModuleEventStore {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b"dan"), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_3 = string::utf8(b"mind_slayer_3002");
        create_account(user1, account_username_3, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_4 = string::utf8(b"mind_slayer_3003");
        create_account(user1, account_username_4, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_5 = string::utf8(b"mind_slayer_3004");
        create_account(user1, account_username_5, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_6 = string::utf8(b"mind_slayer_3005");
        create_account(user1, account_username_6, string::utf8(b""), string::utf8(b""), vector[]);

        follow(user1, account_username_2, account_username_1);
        follow(user1, account_username_3, account_username_1);
        follow(user1, account_username_4, account_username_1);
        follow(user1, account_username_5, account_username_1);
        follow(user1, account_username_6, account_username_1);

        let (account, follower_accounts) = get_account_followers(
            account_username_1,
            2,
            2
        );
        
        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address);
        assert!(
            &account == account_meta_data,
            0
        );

        assert!(
            vector::length(&follower_accounts) == 1,
            0
        );

        {
            let follower_account = vector::borrow(&follower_accounts, 0);

            let follower_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_2
            );
            let follower_account_meta_data = borrow_global<AccountMetaData>(follower_account_address);

            assert!(
                follower_account == follower_account_meta_data,
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_followings_test_not_registered_username(
        admin: &signer, 
        user1: &signer
    ) acquires State, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username = string::utf8(b"mind_slayer_3000");

       let (account, follower_accounts) = get_account_followings(
            account_username,
            20,
            0
        );

        let account_meta_data = AccountMetaData {
            creation_timestamp: 0,
            account_address: @0x0, 
            username: string::utf8(b""),
            name: string::utf8(b""),
            profile_picture_uri: string::utf8(b""),
            bio: string::utf8(b""),
            follower_account_usernames: vector[],
            following_account_usernames: vector[]
        };
        assert!(
            account == account_meta_data,
            0
        );

        assert!(
            vector::length(&follower_accounts) == 0,
            0
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_followings_test_no_followers(
        admin: &signer,
        user1: &signer
    ) acquires State, AccountMetaData, ModuleEventStore {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username, string::utf8(b""), string::utf8(b""), vector[]);

        let (account, follower_accounts) = get_account_followings(
            account_username,
            20,
            0
        );
         
        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address = *table::borrow(
            &account_registry.accounts,
            account_username
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address);
        assert!(
            &account == account_meta_data,
            0
        );

        assert!(
            vector::length(&follower_accounts) == 0,
            0
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_followings_test_partial_first_page(
        admin: &signer, 
        user1: &signer
    ) acquires State, AccountMetaData, ModuleEventStore {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        follow(user1, account_username_2, account_username_1);

        let (account, following_accounts) = get_account_followings(
            account_username_2,
            2,
            0
        );

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address = *table::borrow(
            &account_registry.accounts,
            account_username_2
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address);
        assert!(
            &account == account_meta_data,
            0
        );

        assert!(
            vector::length(&following_accounts) == 1,
            0
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_followings_test_full_first_page(
        admin: &signer,
        user1: &signer
    ) acquires State, AccountMetaData, ModuleEventStore {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_3 = string::utf8(b"mind_slayer_3002");
        create_account(user1, account_username_3, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_4 = string::utf8(b"mind_slayer_3003");
        create_account(user1, account_username_4, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_5 = string::utf8(b"mind_slayer_3004");
        create_account(user1, account_username_5, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_6 = string::utf8(b"mind_slayer_3005");
        create_account(user1, account_username_6, string::utf8(b""), string::utf8(b""), vector[]);

        follow(user1, account_username_1, account_username_2);
        follow(user1, account_username_1, account_username_3);
        follow(user1, account_username_1, account_username_4);
        follow(user1, account_username_1, account_username_5);
        follow(user1, account_username_1, account_username_6);

        let (account, follower_accounts) = get_account_followings(
            account_username_1,
            2,
            0
        );
        
        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address);
        assert!(
            &account == account_meta_data,
            0
        );

        assert!(
            vector::length(&follower_accounts) == 2,
            0
        );

        {
            let follower_account = vector::borrow(&follower_accounts, 0);

            let follower_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_6
            );
            let follower_account_meta_data = borrow_global<AccountMetaData>(follower_account_address);

            assert!(
                follower_account == follower_account_meta_data,
                0
            );
        };

        {
            let follower_account = vector::borrow(&follower_accounts, 1);

            let follower_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_5
            );
            let follower_account_meta_data = borrow_global<AccountMetaData>(follower_account_address);

            assert!(
                follower_account == follower_account_meta_data,
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_followings_test_partial_third_page(
        admin: &signer,
        user1: &signer
    ) acquires State, AccountMetaData, ModuleEventStore {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b"dan"), string::utf8(b""), vector[]);

        let account_username_2 = string::utf8(b"mind_slayer_3001");
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_3 = string::utf8(b"mind_slayer_3002");
        create_account(user1, account_username_3, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_4 = string::utf8(b"mind_slayer_3003");
        create_account(user1, account_username_4, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_5 = string::utf8(b"mind_slayer_3004");
        create_account(user1, account_username_5, string::utf8(b""), string::utf8(b""), vector[]);

        let account_username_6 = string::utf8(b"mind_slayer_3005");
        create_account(user1, account_username_6, string::utf8(b""), string::utf8(b""), vector[]);

        follow(user1, account_username_1, account_username_2);
        follow(user1, account_username_1, account_username_3);
        follow(user1, account_username_1, account_username_4);
        follow(user1, account_username_1, account_username_5);
        follow(user1, account_username_1, account_username_6);

        let (account, follower_accounts) = get_account_followings(
            account_username_1,
            2,
            2
        );
        
        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address);
        assert!(
            &account == account_meta_data,
            0
        );

        assert!(
            vector::length(&follower_accounts) == 1,
            0
        );

        {
            let follower_account = vector::borrow(&follower_accounts, 0);

            let follower_account_address = *table::borrow(
                &account_registry.accounts,
                account_username_2
            );
            let follower_account_meta_data = borrow_global<AccountMetaData>(follower_account_address);

            assert!(
                follower_account == follower_account_meta_data,
                0
            );
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_comments_test_no_registered_account(
        admin: &signer,
        user1: &signer
    ) acquires State, Publications, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        // create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        // create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        // let post_content_1 = string::utf8(b"0");
        // let post_content_2 = string::utf8(b"1");
        // // let post_content_3 = string::utf8(b"2");
        // // let post_content_4 = string::utf8(b"3");
        // let post_content_5 = string::utf8(b"4");

        // // post(user1, account_username_1, post_content_1);
        // post(user1, account_username_2, post_content_1);
        // post(user1, account_username_2, post_content_1);
        // // post(user1, account_username_1, post_content_2);
        // post(user1, account_username_2, post_content_2);
        // // post(user1, account_username_1, post_content_3);
        // // post(user1, account_username_1, post_content_4);
        // post(user1, account_username_2, post_content_5);
        // post(user1, account_username_2, post_content_5);
        // post(user1, account_username_2, post_content_5);
        // // post(user1, account_username_1, post_content_5);

        // // like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        // // like(user1, account_username_2, account_username_1, string::utf8(b"post"), 4);

        // follow(user1, account_username_2, account_username_1);

        let (
            author_account, 
            timeline_comments,
            timeline_posts, 
            post_authors,
            timeline_comment_likes,
            timeline_post_likes
        ) = get_account_comments(account_username_1, account_username_2, 10, 0);

        let account_meta_data = AccountMetaData {
            creation_timestamp: 0,
            account_address: @0x0, 
            username: string::utf8(b""),
            name: string::utf8(b""),
            profile_picture_uri: string::utf8(b""),
            bio: string::utf8(b""),
            follower_account_usernames: vector[],
            following_account_usernames: vector[]
        };
        assert!(
            author_account == account_meta_data,
            0
        );

        assert!(
            vector::length(&timeline_comments) == 0,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 0,
            1
        );
        assert!(
            vector::length(&timeline_comment_likes) == 0,
            0
        );
        assert!(
            vector::length(&timeline_post_likes) == 0,
            1
        );
        assert!(
            vector::length(&post_authors) == 0,
            0
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_comments_tests_empty_first_page(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content_1 = string::utf8(b"0");
        let post_content_2 = string::utf8(b"1");
        // let post_content_3 = string::utf8(b"2");
        // let post_content_4 = string::utf8(b"3");
        let post_content_5 = string::utf8(b"4");

        // post(user1, account_username_1, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_2, post_content_1);
        // post(user1, account_username_1, post_content_2);
        post(user1, account_username_2, post_content_2);
        // post(user1, account_username_1, post_content_3);
        // post(user1, account_username_1, post_content_4);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        // post(user1, account_username_1, post_content_5);

        // like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        // like(user1, account_username_2, account_username_1, string::utf8(b"post"), 4);

        follow(user1, account_username_2, account_username_1);

        let (
            author_account, 
            timeline_comments,
            timeline_posts, 
            post_authors,
            timeline_comment_likes,
            timeline_post_likes
        ) = get_account_comments(account_username_1, account_username_2, 10, 0);

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_1 = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
        assert!(
            &author_account == account_meta_data,
            0
        );

        assert!(
            vector::length(&timeline_comments) == 0,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 0,
            1
        );
        assert!(
            vector::length(&timeline_comment_likes) == 0,
            0
        );
        assert!(
            vector::length(&timeline_post_likes) == 0,
            1
        );
        assert!(
            vector::length(&post_authors) == 0,
            0
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_comments_tests_partial_first_page(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content_1 = string::utf8(b"0");
        let post_content_2 = string::utf8(b"1");
        let post_content_3 = string::utf8(b"2");
        let post_content_4 = string::utf8(b"3");
        let post_content_5 = string::utf8(b"4");

        post(user1, account_username_1, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_1, post_content_2);
        post(user1, account_username_2, post_content_2);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_1, post_content_5);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_2, post_content_5);

        like(user1, account_username_1, account_username_2, string::utf8(b"post"), 0);
        like(user1, account_username_1, account_username_2, string::utf8(b"post"), 4);

        comment(
            user1, 
            account_username_2, 
            string::utf8(b"content"), 
            account_username_1, 
            0
        );
        comment(
            user1, 
            account_username_2, 
            string::utf8(b"content"), 
            account_username_2, 
            0
        );
        comment(
            user1, 
            account_username_2, 
            string::utf8(b"content"), 
            account_username_2, 
            5
        );
        comment(
            user1, 
            account_username_2, 
            string::utf8(b"content"), 
            account_username_2, 
            6
        );
        comment(
            user1, 
            account_username_2, 
            string::utf8(b"content"), 
            account_username_1, 
            0
        );

        like(user1, account_username_1, account_username_2, string::utf8(b"comment"), 1);
        like(user1, account_username_1, account_username_2, string::utf8(b"comment"), 2);

        follow(user1, account_username_2, account_username_1);

        let (
            author_account, 
            timeline_comments,
            timeline_posts, 
            post_authors,
            timeline_comment_likes,
            timeline_post_likes
        ) = get_account_comments(account_username_2, account_username_1, 10, 0);

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_2 = *table::borrow(
            &account_registry.accounts,
            account_username_2
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address_2);
        assert!(
            &author_account == account_meta_data,
            0
        );

        assert!(
            vector::length(&timeline_comments) == 5,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 5,
            1
        );
        assert!(
            vector::length(&timeline_comment_likes) == 5,
            0
        );
        assert!(
            vector::length(&timeline_post_likes) == 5,
            1
        );
        assert!(
            vector::length(&post_authors) == 5,
            0
        );

        {
            let publications = borrow_global<Publications>(account_address_2);
            let comments = &publications.comments;
            let comment = vector::borrow(comments, 4);
            let timeline_comment = vector::borrow(&timeline_comments, 0);
            assert!(
                timeline_comment == comment,
                0
            );

            let comment_likes = &comment.likes;
            let timeline_comment_liked = vector::borrow(&timeline_comment_likes, 0);
            assert!(
                *timeline_comment_liked == vector::contains(comment_likes, &account_username_1),
                0
            );

            {
                let post_author = vector::borrow(&post_authors, 0);
                let post_author_address = *table::borrow(
                    &account_registry.accounts,
                    account_username_1
                );
                let account_meta_data = borrow_global<AccountMetaData>(post_author_address);
                assert!(
                    post_author == account_meta_data,
                    0
                );

                let publications = borrow_global<Publications>(post_author_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, 0);
                let timeline_post = vector::borrow(&timeline_posts, 0);
                assert!(
                    timeline_post == post,
                    0
                );

                let post_likes = &post.likes;
                let timeline_post_liked = vector::borrow(&timeline_post_likes, 0);
                assert!(
                    *timeline_post_liked == vector::contains(post_likes, &account_username_1),
                    0
                );
            }
        };

        {
            let publications = borrow_global<Publications>(account_address_2);
            let comments = &publications.comments;
            let comment = vector::borrow(comments, 3);
            let timeline_comment = vector::borrow(&timeline_comments, 1);
            assert!(
                timeline_comment == comment,
                0
            );

            let comment_likes = &comment.likes;
            let timeline_comment_liked = vector::borrow(&timeline_comment_likes, 1);
            assert!(
                *timeline_comment_liked == vector::contains(comment_likes, &account_username_1),
                0
            );

            {
                let post_author = vector::borrow(&post_authors, 1);
                let post_author_address = *table::borrow(
                    &account_registry.accounts,
                    account_username_2
                );
                let account_meta_data = borrow_global<AccountMetaData>(post_author_address);
                assert!(
                    post_author == account_meta_data,
                    0
                );

                let publications = borrow_global<Publications>(post_author_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, 6);
                let timeline_post = vector::borrow(&timeline_posts, 1);
                assert!(
                    timeline_post == post,
                    0
                );

                let post_likes = &post.likes;
                let timeline_post_liked = vector::borrow(&timeline_post_likes, 1);
                assert!(
                    *timeline_post_liked == vector::contains(post_likes, &account_username_1),
                    0
                );
            }
        };

        {
            let publications = borrow_global<Publications>(account_address_2);
            let comments = &publications.comments;
            let comment = vector::borrow(comments, 2);
            let timeline_comment = vector::borrow(&timeline_comments, 2);
            assert!(
                timeline_comment == comment,
                0
            );

            let comment_likes = &comment.likes;
            let timeline_comment_liked = vector::borrow(&timeline_comment_likes, 2);
            assert!(
                *timeline_comment_liked == vector::contains(comment_likes, &account_username_1),
                0
            );

            {
                let post_author = vector::borrow(&post_authors, 2);
                let post_author_address = *table::borrow(
                    &account_registry.accounts,
                    account_username_2
                );
                let account_meta_data = borrow_global<AccountMetaData>(post_author_address);
                assert!(
                    post_author == account_meta_data,
                    0
                );

                let publications = borrow_global<Publications>(post_author_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, 5);
                let timeline_post = vector::borrow(&timeline_posts, 2);
                assert!(
                    timeline_post == post,
                    0
                );

                let post_likes = &post.likes;
                let timeline_post_liked = vector::borrow(&timeline_post_likes, 2);
                assert!(
                    *timeline_post_liked == vector::contains(post_likes, &account_username_1),
                    0
                );
            }
        };

        {
            let publications = borrow_global<Publications>(account_address_2);
            let comments = &publications.comments;
            let comment = vector::borrow(comments, 1);
            let timeline_comment = vector::borrow(&timeline_comments, 3);
            assert!(
                timeline_comment == comment,
                0
            );

            let comment_likes = &comment.likes;
            let timeline_comment_liked = vector::borrow(&timeline_comment_likes, 3);
            assert!(
                *timeline_comment_liked == vector::contains(comment_likes, &account_username_1),
                0
            );

            {
                let post_author = vector::borrow(&post_authors, 3);
                let post_author_address = *table::borrow(
                    &account_registry.accounts,
                    account_username_2
                );
                let account_meta_data = borrow_global<AccountMetaData>(post_author_address);
                assert!(
                    post_author == account_meta_data,
                    0
                );

                let publications = borrow_global<Publications>(post_author_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, 0);
                let timeline_post = vector::borrow(&timeline_posts, 3);
                assert!(
                    timeline_post == post,
                    0
                );

                let post_likes = &post.likes;
                let timeline_post_liked = vector::borrow(&timeline_post_likes, 3);
                assert!(
                    *timeline_post_liked == vector::contains(post_likes, &account_username_1),
                    0
                );
            }
        };

        {
            let publications = borrow_global<Publications>(account_address_2);
            let comments = &publications.comments;
            let comment = vector::borrow(comments, 0);
            let timeline_comment = vector::borrow(&timeline_comments, 4);
            assert!(
                timeline_comment == comment,
                0
            );

            let comment_likes = &comment.likes;
            let timeline_comment_liked = vector::borrow(&timeline_comment_likes, 4);
            assert!(
                *timeline_comment_liked == vector::contains(comment_likes, &account_username_1),
                0
            );

            {
                let post_author = vector::borrow(&post_authors, 4);
                let post_author_address = *table::borrow(
                    &account_registry.accounts,
                    account_username_1
                );
                let account_meta_data = borrow_global<AccountMetaData>(post_author_address);
                assert!(
                    post_author == account_meta_data,
                    0
                );

                let publications = borrow_global<Publications>(post_author_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, 0);
                let timeline_post = vector::borrow(&timeline_posts, 4);
                assert!(
                    timeline_post == post,
                    0
                );

                let post_likes = &post.likes;
                let timeline_post_liked = vector::borrow(&timeline_post_likes, 4);
                assert!(
                    *timeline_post_liked == vector::contains(post_likes, &account_username_1),
                    0
                );
            }
        };
        
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_comments_tests_full_second_page(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content_1 = string::utf8(b"0");
        let post_content_2 = string::utf8(b"1");
        let post_content_3 = string::utf8(b"2");
        let post_content_4 = string::utf8(b"3");
        let post_content_5 = string::utf8(b"4");

        post(user1, account_username_1, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_1, post_content_2);
        post(user1, account_username_2, post_content_2);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_1, post_content_5);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_2, post_content_5);

        like(user1, account_username_1, account_username_2, string::utf8(b"post"), 0);
        like(user1, account_username_1, account_username_2, string::utf8(b"post"), 4);

        comment(
            user1, 
            account_username_2, 
            string::utf8(b"content"), 
            account_username_1, 
            0
        );
        comment(
            user1, 
            account_username_2, 
            string::utf8(b"content"), 
            account_username_2, 
            0
        );
        comment(
            user1, 
            account_username_2, 
            string::utf8(b"content"), 
            account_username_2, 
            5
        );
        comment(
            user1, 
            account_username_2, 
            string::utf8(b"content"), 
            account_username_2, 
            6
        );
        comment(
            user1, 
            account_username_2, 
            string::utf8(b"content"), 
            account_username_1, 
            0
        );

        like(user1, account_username_1, account_username_2, string::utf8(b"comment"), 1);
        like(user1, account_username_1, account_username_2, string::utf8(b"comment"), 2);

        follow(user1, account_username_2, account_username_1);

        let (
            author_account, 
            timeline_comments,
            timeline_posts, 
            post_authors,
            timeline_comment_likes,
            timeline_post_likes
        ) = get_account_comments(account_username_2, account_username_1, 2, 1);

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_2 = *table::borrow(
            &account_registry.accounts,
            account_username_2
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address_2);
        assert!(
            &author_account == account_meta_data,
            0
        );

        assert!(
            vector::length(&timeline_comments) == 2,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 2,
            1
        );
        assert!(
            vector::length(&timeline_comment_likes) == 2,
            0
        );
        assert!(
            vector::length(&timeline_post_likes) == 2,
            1
        );
        assert!(
            vector::length(&post_authors) == 2,
            0
        );

        {
            let publications = borrow_global<Publications>(account_address_2);
            let comments = &publications.comments;
            let comment = vector::borrow(comments, 2);
            let timeline_comment = vector::borrow(&timeline_comments, 0);
            assert!(
                timeline_comment == comment,
                0
            );

            let comment_likes = &comment.likes;
            let timeline_comment_liked = vector::borrow(&timeline_comment_likes, 0);
            assert!(
                *timeline_comment_liked == vector::contains(comment_likes, &account_username_1),
                0
            );

            {
                let post_author = vector::borrow(&post_authors, 0);
                let post_author_address = *table::borrow(
                    &account_registry.accounts,
                    account_username_2
                );
                let account_meta_data = borrow_global<AccountMetaData>(post_author_address);
                assert!(
                    post_author == account_meta_data,
                    0
                );

                let publications = borrow_global<Publications>(post_author_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, 5);
                let timeline_post = vector::borrow(&timeline_posts, 0);
                assert!(
                    timeline_post == post,
                    0
                );

                let post_likes = &post.likes;
                let timeline_post_liked = vector::borrow(&timeline_post_likes, 0);
                assert!(
                    *timeline_post_liked == vector::contains(post_likes, &account_username_1),
                    0
                );
            }
        };

        {
            let publications = borrow_global<Publications>(account_address_2);
            let comments = &publications.comments;
            let comment = vector::borrow(comments, 1);
            let timeline_comment = vector::borrow(&timeline_comments, 1);
            assert!(
                timeline_comment == comment,
                0
            );

            let comment_likes = &comment.likes;
            let timeline_comment_liked = vector::borrow(&timeline_comment_likes, 1);
            assert!(
                *timeline_comment_liked == vector::contains(comment_likes, &account_username_1),
                0
            );

            {
                let post_author = vector::borrow(&post_authors, 1);
                let post_author_address = *table::borrow(
                    &account_registry.accounts,
                    account_username_2
                );
                let account_meta_data = borrow_global<AccountMetaData>(post_author_address);
                assert!(
                    post_author == account_meta_data,
                    0
                );

                let publications = borrow_global<Publications>(post_author_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, 0);
                let timeline_post = vector::borrow(&timeline_posts, 1);
                assert!(
                    timeline_post == post,
                    0
                );

                let post_likes = &post.likes;
                let timeline_post_liked = vector::borrow(&timeline_post_likes, 1);
                assert!(
                    *timeline_post_liked == vector::contains(post_likes, &account_username_1),
                    0
                );
            }
        };
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_comments_tests_partial_third_page(
        admin: &signer,
        user1: &signer
    ) acquires State, ModuleEventStore, Publications, AccountMetaData, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);


        let post_content_1 = string::utf8(b"0");
        let post_content_2 = string::utf8(b"1");
        let post_content_3 = string::utf8(b"2");
        let post_content_4 = string::utf8(b"3");
        let post_content_5 = string::utf8(b"4");

        post(user1, account_username_1, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_2, post_content_1);
        post(user1, account_username_1, post_content_2);
        post(user1, account_username_2, post_content_2);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_2, post_content_5);
        post(user1, account_username_1, post_content_5);
        post(user1, account_username_1, post_content_3);
        post(user1, account_username_1, post_content_4);
        post(user1, account_username_2, post_content_5);

        like(user1, account_username_1, account_username_2, string::utf8(b"post"), 0);
        like(user1, account_username_1, account_username_2, string::utf8(b"post"), 4);

        comment(
            user1, 
            account_username_2, 
            string::utf8(b"content"), 
            account_username_1, 
            0
        );
        comment(
            user1, 
            account_username_2, 
            string::utf8(b"content"), 
            account_username_2, 
            0
        );
        comment(
            user1, 
            account_username_2, 
            string::utf8(b"content"), 
            account_username_2, 
            5
        );
        comment(
            user1, 
            account_username_2, 
            string::utf8(b"content"), 
            account_username_2, 
            6
        );
        comment(
            user1, 
            account_username_2, 
            string::utf8(b"content"), 
            account_username_1, 
            0
        );

        like(user1, account_username_1, account_username_2, string::utf8(b"comment"), 1);
        like(user1, account_username_1, account_username_2, string::utf8(b"comment"), 2);

        follow(user1, account_username_2, account_username_1);

        let (
            author_account, 
            timeline_comments,
            timeline_posts, 
            post_authors,
            timeline_comment_likes,
            timeline_post_likes
        ) = get_account_comments(account_username_2, account_username_1, 2, 2);

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_2 = *table::borrow(
            &account_registry.accounts,
            account_username_2
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address_2);
        assert!(
            &author_account == account_meta_data,
            0
        );

        assert!(
            vector::length(&timeline_comments) == 1,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 1,
            1
        );
        assert!(
            vector::length(&timeline_comment_likes) == 1,
            0
        );
        assert!(
            vector::length(&timeline_post_likes) == 1,
            1
        );
        assert!(
            vector::length(&post_authors) == 1,
            0
        );

        {
            let publications = borrow_global<Publications>(account_address_2);
            let comments = &publications.comments;
            let comment = vector::borrow(comments, 0);
            let timeline_comment = vector::borrow(&timeline_comments, 0);
            assert!(
                timeline_comment == comment,
                0
            );

            let comment_likes = &comment.likes;
            let timeline_comment_liked = vector::borrow(&timeline_comment_likes, 0);
            assert!(
                *timeline_comment_liked == vector::contains(comment_likes, &account_username_1),
                0
            );

            {
                let post_author = vector::borrow(&post_authors, 0);
                let post_author_address = *table::borrow(
                    &account_registry.accounts,
                    account_username_1
                );
                let account_meta_data = borrow_global<AccountMetaData>(post_author_address);
                assert!(
                    post_author == account_meta_data,
                    0
                );

                let publications = borrow_global<Publications>(post_author_address);
                let posts = &publications.posts;
                let post = vector::borrow(posts, 0);
                let timeline_post = vector::borrow(&timeline_posts, 0);
                assert!(
                    timeline_post == post,
                    0
                );

                let post_likes = &post.likes;
                let timeline_post_liked = vector::borrow(&timeline_post_likes, 0);
                assert!(
                    *timeline_post_liked == vector::contains(post_likes, &account_username_1),
                    0
                );
            }
        };
        
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_liked_posts_tests_username_not_registered(
        admin: &signer, 
        user1: &signer
    ) acquires State, Publications, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let (
            account, 
            timeline_posts,
            post_authors,
            timeline_post_likes
        ) = get_account_liked_posts(string::utf8(b""), string::utf8(b""), 10, 0);

        let account_meta_data = AccountMetaData {
            creation_timestamp: 0,
            account_address: @0x0, 
            username: string::utf8(b""),
            name: string::utf8(b""),
            profile_picture_uri: string::utf8(b""),
            bio: string::utf8(b""),
            follower_account_usernames: vector[],
            following_account_usernames: vector[]
        };
        assert!(
            account == account_meta_data,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 0,
            0
        );
        assert!(
            vector::length(&timeline_post_likes) == 0,
            0
        );
        assert!(
            vector::length(&post_authors) == 0,
            0
        );

    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_liked_posts_tests_no_liked_posts(
        admin: &signer, 
        user1: &signer
    ) acquires State, Publications, AccountMetaData, ModuleEventStore {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let (
            account, 
            timeline_posts,
            post_authors,
            timeline_post_likes
        ) = get_account_liked_posts(account_username_1, account_username_2, 10, 0);

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_1 = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
        
        assert!(
            &account == account_meta_data,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 0,
            0
        );
        assert!(
            vector::length(&timeline_post_likes) == 0,
            0
        );
        assert!(
            vector::length(&post_authors) == 0,
            0
        );

    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_liked_posts_tests_partial_first_page(
        admin: &signer, 
        user1: &signer
    ) acquires State, Publications, AccountMetaData, ModuleEventStore, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        post(user1, account_username_1, string::utf8(b"0"));
        post(user1, account_username_1, string::utf8(b"1"));
        post(user1, account_username_1, string::utf8(b"2"));
        post(user1, account_username_1, string::utf8(b"3"));

        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 3);

        like(user1, account_username_1, account_username_1, string::utf8(b"post"), 0);

        let (
            account, 
            timeline_posts,
            post_authors,
            timeline_post_likes
        ) = get_account_liked_posts(account_username_2, account_username_1, 10, 0);

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_username_2 = *table::borrow(
            &account_registry.accounts,
            account_username_2
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_username_2);
        
        assert!(
            &account == account_meta_data,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 2,
            0
        );
        assert!(
            vector::length(&timeline_post_likes) == 2,
            0
        );
        assert!(
            vector::length(&post_authors) == 2,
            0
        );


    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_liked_posts_tests_full_first_page(
        admin: &signer, 
        user1: &signer
    ) acquires State, Publications, AccountMetaData, ModuleEventStore, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        post(user1, account_username_1, string::utf8(b"0"));
        post(user1, account_username_1, string::utf8(b"1"));
        post(user1, account_username_1, string::utf8(b"2"));
        post(user1, account_username_1, string::utf8(b"3"));

        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 3);

        like(user1, account_username_1, account_username_1, string::utf8(b"post"), 0);

        let (
            account, 
            timeline_posts,
            post_authors,
            timeline_post_likes
        ) = get_account_liked_posts(account_username_2, account_username_1, 1, 0);

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_username_2 = *table::borrow(
            &account_registry.accounts,
            account_username_2
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_username_2);
        
        assert!(
            &account == account_meta_data,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 1,
            0
        );
        assert!(
            vector::length(&timeline_post_likes) == 1,
            0
        );
        assert!(
            vector::length(&post_authors) == 1,
            0
        );


    }

     #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_liked_posts_tests_empty_third_page(
        admin: &signer, 
        user1: &signer
    ) acquires State, Publications, AccountMetaData, ModuleEventStore, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        post(user1, account_username_1, string::utf8(b"0"));
        post(user1, account_username_1, string::utf8(b"1"));
        post(user1, account_username_1, string::utf8(b"2"));
        post(user1, account_username_1, string::utf8(b"3"));

        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 0);
        like(user1, account_username_2, account_username_1, string::utf8(b"post"), 3);

        like(user1, account_username_1, account_username_1, string::utf8(b"post"), 0);

        let (
            account, 
            timeline_posts,
            post_authors,
            timeline_post_likes
        ) = get_account_liked_posts(account_username_2, account_username_1, 1, 3);

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_username_2 = *table::borrow(
            &account_registry.accounts,
            account_username_2
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_username_2);
        
        assert!(
            &account == account_meta_data,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 0,
            0
        );
        assert!(
            vector::length(&timeline_post_likes) == 0,
            0
        );
        assert!(
            vector::length(&post_authors) == 0,
            0
        );


    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_liked_comments_tests_username_not_registered(
        admin: &signer, 
        user1: &signer
    ) acquires State, Publications, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let (
            account, 
            timeline_comments,
            comment_authors, 
            timeline_posts,
            post_authors,
            timeline_comment_likes,
            timeline_post_likes
        ) = get_account_liked_comments(string::utf8(b""), string::utf8(b""), 10, 0);

        let account_meta_data = AccountMetaData {
            creation_timestamp: 0,
            account_address: @0x0, 
            username: string::utf8(b""),
            name: string::utf8(b""),
            profile_picture_uri: string::utf8(b""),
            bio: string::utf8(b""),
            follower_account_usernames: vector[],
            following_account_usernames: vector[]
        };
        assert!(
            account == account_meta_data,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 0,
            0
        );
        assert!(
            vector::length(&timeline_post_likes) == 0,
            0
        );
        assert!(
            vector::length(&post_authors) == 0,
            0
        );
        assert!(
            vector::length(&timeline_comments) == 0,
            0
        );
        assert!(
            vector::length(&timeline_comment_likes) == 0,
            0
        );
        assert!(
            vector::length(&comment_authors) == 0,
            0
        );

    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_liked_comments_tests_no_liked_comments(
        admin: &signer, 
        user1: &signer
    ) acquires State, Publications, AccountMetaData, ModuleEventStore {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        let (
            account, 
            timeline_comments,
            comment_authors, 
            timeline_posts,
            post_authors,
            timeline_comment_likes,
            timeline_post_likes
        ) = get_account_liked_comments(account_username_1, account_username_2, 10, 0);

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_1 = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
        assert!(
            &account == account_meta_data,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 0,
            0
        );
        assert!(
            vector::length(&timeline_post_likes) == 0,
            0
        );
        assert!(
            vector::length(&post_authors) == 0,
            0
        );
        assert!(
            vector::length(&timeline_comments) == 0,
            0
        );
        assert!(
            vector::length(&timeline_comment_likes) == 0,
            0
        );
        assert!(
            vector::length(&comment_authors) == 0,
            0
        );

    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_liked_comments_tests_full_first_page(
        admin: &signer, 
        user1: &signer
    ) acquires State, Publications, AccountMetaData, ModuleEventStore, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        post(user1, account_username_1, string::utf8(b"0"));
        post(user1, account_username_2, string::utf8(b"0"));

        comment(
            user1, 
            account_username_2, 
            string::utf8(b"content"), 
            account_username_1, 
            0
        );
        comment(
            user1, 
            account_username_2, 
            string::utf8(b"content"), 
            account_username_2, 
            0
        );
        comment(
            user1, 
            account_username_2, 
            string::utf8(b"content"), 
            account_username_2, 
            0
        );

        like(user1, account_username_1, account_username_2, string::utf8(b"comment"), 0);
        like(user1, account_username_1, account_username_2, string::utf8(b"comment"), 1);
        like(user1, account_username_1, account_username_2, string::utf8(b"comment"), 2);

        let (
            account, 
            timeline_comments,
            comment_authors, 
            timeline_posts,
            post_authors,
            timeline_comment_likes,
            timeline_post_likes
        ) = get_account_liked_comments(account_username_1, account_username_2, 2, 0);

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_1 = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
        assert!(
            &account == account_meta_data,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 2,
            0
        );
        assert!(
            vector::length(&timeline_post_likes) == 2,
            0
        );
        assert!(
            vector::length(&post_authors) == 2,
            0
        );
        assert!(
            vector::length(&timeline_comments) == 2,
            0
        );
        assert!(
            vector::length(&timeline_comment_likes) == 2,
            0
        );
        assert!(
            vector::length(&comment_authors) == 2,
            0
        );

    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_account_liked_comments_tests_partial_first_page(
        admin: &signer, 
        user1: &signer
    ) acquires State, Publications, AccountMetaData, ModuleEventStore, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        let account_username_2 = string::utf8(b"mind_slayer_3001");

        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);
        create_account(user1, account_username_2, string::utf8(b""), string::utf8(b""), vector[]);

        post(user1, account_username_1, string::utf8(b"0"));
        post(user1, account_username_2, string::utf8(b"0"));

        comment(
            user1, 
            account_username_2, 
            string::utf8(b"content"), 
            account_username_1, 
            0
        );
        comment(
            user1, 
            account_username_2, 
            string::utf8(b"content"), 
            account_username_2, 
            0
        );
        comment(
            user1, 
            account_username_2, 
            string::utf8(b"content"), 
            account_username_2, 
            0
        );

        like(user1, account_username_1, account_username_2, string::utf8(b"comment"), 0);
        like(user1, account_username_1, account_username_2, string::utf8(b"comment"), 1);
        like(user1, account_username_1, account_username_2, string::utf8(b"comment"), 2);

        let (
            account, 
            timeline_comments,
            comment_authors, 
            timeline_posts,
            post_authors,
            timeline_comment_likes,
            timeline_post_likes
        ) = get_account_liked_comments(account_username_1, account_username_2, 3, 0);

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_1 = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
        assert!(
            &account == account_meta_data,
            0
        );
        assert!(
            vector::length(&timeline_posts) == 3,
            0
        );
        assert!(
            vector::length(&timeline_post_likes) == 3,
            0
        );
        assert!(
            vector::length(&post_authors) == 3,
            0
        );
        assert!(
            vector::length(&timeline_comments) == 3,
            0
        );
        assert!(
            vector::length(&timeline_comment_likes) == 3,
            0
        );
        assert!(
            vector::length(&comment_authors) == 3,
            0
        );

    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_post_test_no_registered_username(
        admin: &signer,
        user1: &signer
    ) acquires State, Publications, AccountMetaData {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let (
            author_account_meta_data, 
            post, 
            liked, 
            comments, 
            comment_authors
        ) = get_post(string::utf8(b""), string::utf8(b""), 4, 10, 0);

        let account_meta_data = AccountMetaData {
            creation_timestamp: 0,
            account_address: @0x0, 
            username: string::utf8(b""),
            name: string::utf8(b""),
            profile_picture_uri: string::utf8(b""),
            bio: string::utf8(b""),
            follower_account_usernames: vector[],
            following_account_usernames: vector[]
        };
        assert!(
            author_account_meta_data == account_meta_data,
            0
        );
        let empty_post = Post {
            id: 0,
            timestamp: 0,
            content: string::utf8(b""),
            comments: vector[],
            likes: vector[]
        };
        assert!(
            post == empty_post,
            0
        );
        assert!(
            liked == false,
            0
        );
        assert!(
            vector::length(&comments) == 0,
            0
        );
        assert!(
            vector::length(&comment_authors) == 0,
            0
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_post_test_post_does_not_exist(
        admin: &signer,
        user1: &signer
    ) acquires State, Publications, AccountMetaData, ModuleEventStore {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        let (
            author_account_meta_data, 
            post, 
            liked, 
            comments, 
            comment_authors
        ) = get_post(account_username_1, account_username_1, 4, 10, 0);

        let account_meta_data = AccountMetaData {
            creation_timestamp: 0,
            account_address: @0x0, 
            username: string::utf8(b""),
            name: string::utf8(b""),
            profile_picture_uri: string::utf8(b""),
            bio: string::utf8(b""),
            follower_account_usernames: vector[],
            following_account_usernames: vector[]
        };
        assert!(
            author_account_meta_data == account_meta_data,
            0
        );
        let empty_post = Post {
            id: 0,
            timestamp: 0,
            content: string::utf8(b""),
            comments: vector[],
            likes: vector[]
        };
        assert!(
            post == empty_post,
            0
        );
        assert!(
            liked == false,
            0
        );
        assert!(
            vector::length(&comments) == 0,
            0
        );
        assert!(
            vector::length(&comment_authors) == 0,
            0
        );
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun get_post_test_post(
        admin: &signer,
        user1: &signer
    ) acquires State, Publications, AccountMetaData, ModuleEventStore, GlobalTimeline {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user1);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        
        init_module(admin);

        let account_username_1 = string::utf8(b"mind_slayer_3000");
        create_account(user1, account_username_1, string::utf8(b""), string::utf8(b""), vector[]);

        post(user1, account_username_1, string::utf8(b"content"));

        let (
            author_account_meta_data, 
            retrieved_post, 
            liked, 
            comments, 
            comment_authors
        ) = get_post(account_username_1, account_username_1, 0, 10, 0);

        let expected_resource_address = account::create_resource_address(&@overmind, SEED);
        let state = borrow_global<State>(expected_resource_address);
        let account_registry = &state.account_registry;

        let account_address_1 = *table::borrow(
            &account_registry.accounts,
            account_username_1
        );
        let account_meta_data = borrow_global<AccountMetaData>(account_address_1);
        assert!(
            &author_account_meta_data == account_meta_data,
            0
        );

        let publications = borrow_global<Publications>(account_address_1);
        let posts = &publications.posts;
        let post = vector::borrow(posts, 0);
        assert!(
            &retrieved_post == post,
            0
        );
        assert!(
            liked == false,
            0
        );
        assert!(
            vector::length(&comments) == 0,
            0
        );
        assert!(
            vector::length(&comment_authors) == 0,
            0
        );
    }
}
