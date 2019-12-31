defmodule TwitterEngine do

    @hashTagRegex  ~r(\B#[a-zA-Z0-9_]+\b)
    @userMentionsRegex ~r(\B@[a-zA-Z0-9-_]+\b)
    
    def start() do
        GenServer.start_link(__MODULE__, [], name: :twitter_engine)
    end

    def init(state) do
        #Table Structure
        #:user_details : {userid, username, password}
        :ets.new(:user_details, [:set, :public, :named_table])
        #:user_tweets : {userid, %{tweet_id1: tweet1, tweet_id2: tweet2}}
        :ets.new(:user_tweets, [:set, :public, :named_table])
        #:newsfeed: {userid, [[user_id1, tweet_id1],[user_id2, tweet_id2]]}
        :ets.new(:newsfeed, [:set, :public, :named_table])
        #:active_users : {userid, true/false}}
        :ets.new(:active_users, [:set, :public, :named_table])
        #:tweets_pending: {userid, [[user_id1, tweet_id1],[user_id2, tweet_id2]]}
        :ets.new(:undelivered_tweets, [:set, :public, :named_table])
        #:follower_list : {userid, [user1,user2..]}
        #Shows List of followers of are following this user
        :ets.new(:follower_list, [:set, :public, :named_table])
        #:following_list : {userid, [user1,user2..]}
        #List of Users to whom this user is following
        :ets.new(:following_list, [:set, :public, :named_table])
        #:mentions : {userid, [[user_id1, tweet_id1],[user_id2, tweet_id2]]}
        :ets.new(:mentions, [:set, :public, :named_table])
        #:hashtags : {hashtag1, [[user_id1, tweet_id1],[user_id2, tweet_id2]]}
        :ets.new(:hashtags, [:set, :public, :named_table])
        #:hashtags : {hashtag1, [[user_id1, tweet_id1],[user_id2, tweet_id2]]}
        :ets.new(:group_users, [:set, :public, :named_table])
        #:hashtags : {hashtag1, [[user_id1, tweet_id1],[user_id2, tweet_id2]]}
        :ets.new(:group_messages, [:set, :public, :named_table])
        #:hashtags : {hashtag1, [[user_id1, tweet_id1],[user_id2, tweet_id2]]}
        :ets.new(:user_groups, [:set, :public, :named_table])
        {:ok, state}
    end

    def handle_call({:register_user,user_handle, user_name, password}, _from , state) do
        if (!checkIfUserExists(user_handle)) do
            :ets.insert(:user_details,{user_handle,user_name,password})
            :ets.insert(:active_users,{user_handle, true})
            {:reply,:success,state}
        else
            {:reply,:fail,state}
        end
    end

    def handle_call({:login_user,received_user_id, received_password}, _from , state) do
        userdata = getData(:user_details, received_user_id)
        if(userdata != []) do
            [user_id,user_name,actual_password] = userdata
            if(actual_password == received_password) do
                #Login Successful
                IO.puts "Login Successfull for "<>user_id
                :ets.insert(:active_users,{user_id, true})
                pendingTweets = getData(:undelivered_tweets, user_id)
                if(pendingTweets!=[]) do
                    Enum.each(pendingTweets, fn(tweet_data)-> 
                        from_user_id = Enum.at(tweet_data,0)
                        tweet_id = Enum.at(tweet_data,1)
                        tweet = getData(:user_tweets, from_user_id)
                        addTweetToNewsFeed(received_user_id,from_user_id,tweet_id)
                        GenServer.cast(TwitterSimulator.get_pid(user_id),{:news_feed, from_user_id,tweet_id, tweet[tweet_id]})
                    end)
                end
                :ets.delete(:undelivered_tweets, user_id)
                {:reply, :success, state}
            else
                IO.puts "Invalid Password"
                {:reply, :failed, state}
            end
        else
            IO.puts "No User exist"
            {:reply, :not_exist, state}
        end
    end

    def handle_call({:logout_user,user_id}, _from , state) do
        IO.puts "Logout Successfull for "<>user_id
        :ets.insert(:active_users,{user_id, false})
        {:reply, :ok , state}
    end

    def checkIfUserExists(user_handle) do
        case :ets.lookup(:user_details,user_handle) do
            [{user_handle,_, _}] -> true
            [] -> false
        end
    end

    def handle_call({:delete_user,user_handle}, _from , state) do
        if (checkIfUserExists(user_handle)) do
            :ets.delete(:user_tweets, user_handle)
            :ets.delete(:newsfeed, user_handle)
            :ets.delete(:active_users, user_handle)
            :ets.delete(:undelivered_tweets, user_handle)
            :ets.delete(:follower_list, user_handle)
            IO.puts "User Deleted"
            {:reply,:ok,state}
        else
            {:reply,"User #{user_handle} does not exist",state}
        end
    end

    def handle_cast({:user_followers, user_id, follower_id}, state) do
        #update followers table
        current_follower_list = getData(:follower_list, follower_id)
        current_follower_list = current_follower_list ++ [user_id]
        :ets.insert(:follower_list,{follower_id,current_follower_list})

        #update following table
        current_following_list = getData(:following_list, user_id)
        current_following_list = current_following_list ++ [follower_id]
        :ets.insert(:following_list,{user_id,current_following_list})

        {:noreply, state}
    end

    def handle_cast({:tweet_message, tweet, from_user_id}, state) do
        #add the tweet in the tweet list
        tweet_id = addTweetToList(tweet,from_user_id)
        #parse the tweet for hashtags
        if(String.contains?(tweet,"#")) do       
            addHashTagToList(from_user_id, tweet_id, tweet)
        end
        #send the tweet to all the followers and to the mentions
        sender_list = if(String.contains?(tweet,"@")) do
            listOfUserMentions = addMentionToList(from_user_id, tweet_id, tweet)
            Enum.uniq(getData(:follower_list, from_user_id) ++ (listOfUserMentions |> Enum.map(fn(x)->  String.replace(x,"@","")end)))
        else
            getData(:follower_list, from_user_id)
        end
        sender_list = sender_list ++ [from_user_id]
        Enum.each(sender_list, fn(follower_id) ->
            isActive = getData(:active_users, follower_id)
            if (isActive) do
                addTweetToNewsFeed(follower_id,from_user_id,tweet_id)
                GenServer.cast(TwitterSimulator.get_pid(follower_id),{:news_feed, from_user_id,tweet_id, tweet})
            else
                addTweetToPendingList(follower_id, from_user_id, tweet_id)
            end
        end)
        TwitterWeb.MessageChannel.distributeTweet(from_user_id, tweet_id, tweet, sender_list)
        #IO.puts("Followers: #{Enum.count(sender_list)} - Time Taken: #{time_difference} milliseconds")
        #send(Process.whereis(:twitter), {:performance, Enum.count(sender_list), time_difference})
        {:noreply, state}
    end

    def addTweetToPendingList(for_user_id, from_user_id, tweet_id) do
        #IO.puts "Putting in Pending List message for #{for_user_id} from #{from_user_id} and tweetid #{tweet_id}"
        mentionsList = getData(:undelivered_tweets, for_user_id)
        mentionsList =  mentionsList ++ [[from_user_id,tweet_id]]
        :ets.insert(:undelivered_tweets,{for_user_id,mentionsList})
    end


    def addTweetToList(tweet, user_id) do
        tweet_map = getData(:user_tweets,user_id)
        if(tweet_map == []) do
            tweet_map = %{length(tweet_map)=> tweet}
            :ets.insert(:user_tweets,{user_id,tweet_map})
        else
            tweet_map = Map.put(tweet_map,map_size(tweet_map), tweet)
            :ets.insert(:user_tweets,{user_id,tweet_map})
        end
        map_size(getData(:user_tweets,user_id))-1
    end

    def addTweetToNewsFeed(user_id, from_user_id, tweet_id) do
        newsFeedList = getData(:newsfeed, user_id)
        newsFeedList =  newsFeedList ++ [[from_user_id,tweet_id]]
        :ets.insert(:newsfeed,{user_id,newsFeedList})
    end

    def addHashTagToList(user_id, tweet_id, tweet) do
        listOfHashTags = Regex.scan(@hashTagRegex, tweet)
        listOfHashTags = List.flatten(listOfHashTags)
        Enum.each(listOfHashTags, fn(hashtag)-> 
            hashtagList = getData(:hashtags, hashtag)
            hashtagList =  hashtagList ++ [[user_id,tweet_id]]
            :ets.insert(:hashtags,{hashtag,hashtagList})
        end)
    end

    def addMentionToList(user_id, tweet_id, tweet) do
        listOfUserMentions = Regex.scan(@userMentionsRegex, tweet)
        listOfUserMentions = List.flatten(listOfUserMentions)
        Enum.each(listOfUserMentions, fn(mention_id)-> 
            mention_id = String.replace(mention_id, "@", "")
            mentionsList = getData(:mentions, mention_id)
            mentionsList =  mentionsList ++ [[user_id,tweet_id]]
            :ets.insert(:mentions,{mention_id,mentionsList})
        end)
        listOfUserMentions
    end

    def handle_cast({:retweet_message, from_user_id, of_user_id, tweet_id}, state) do
        #send the tweet to all the followers 
        sender_list = getData(:follower_list, from_user_id)
        tweet = getData(:user_tweets, of_user_id)
        retweet_msg = "Retweet:"<>of_user_id<>":tweetid:"<>tweet_id<>":tweet:"<>tweet[String.to_integer(tweet_id)]
        tweet_id = addTweetToList(retweet_msg,from_user_id)
        sender_list = sender_list ++ [from_user_id]
        Enum.each(sender_list, fn(follower_id) ->
            isActive = getData(:active_users, follower_id)
            if (isActive) do
                addTweetToNewsFeed(follower_id,from_user_id,tweet_id)
                GenServer.cast(TwitterSimulator.get_pid(follower_id),{:news_feed,from_user_id,tweet_id, retweet_msg})
            else
                addTweetToPendingList(follower_id, from_user_id, tweet_id)
            end
        end)
        TwitterWeb.MessageChannel.distributeRetweet(from_user_id, tweet_id, retweet_msg, sender_list)
        {:noreply, state}
    end

    def handle_call({:get_messages_with_hashtags, search_hashtag}, _from, state) do
        hashtag_message_list = getData(:hashtags, search_hashtag)
        message_list = Enum.reduce(hashtag_message_list, [], fn(message_data, acc) ->
            from_user = Enum.at(message_data,0)
            tweet = getData(:user_tweets, Enum.at(message_data,0))
            acc = acc ++ [[from_user, tweet[Enum.at(message_data,1)]]]
        end)
        {:reply, message_list, state}
    end

    def handle_call({:get_messages_with_mentions, search_mention}, _from, state) do
        IO.inspect search_mention, label: "search_mention"
        mentions_message_list = getData(:mentions, search_mention)
        IO.inspect mentions_message_list, label: "mention list"
        message_list = Enum.reduce(mentions_message_list, [], fn(message_data, acc) ->
            from_user = Enum.at(message_data,0)
            tweet = getData(:user_tweets, Enum.at(message_data,0))
            acc = acc ++ [[from_user, tweet[Enum.at(message_data,1)]]]
        end)
        IO.inspect message_list, label: "message list"
        {:reply, message_list, state}
    end


    def getData(table_name, user_id) do
        case :ets.lookup(table_name,user_id) do
            [{user_handle,user_name, password}] -> [user_handle, user_name,password]
            [{user_id,data}] -> data
            [] -> []
        end
    end


    def handle_call({:get_followers_list, user_id}, _from, state) do
        databaseValue = getData(:follower_list, user_id)
        {:reply, databaseValue, state}
    end

    def handle_call({:get_tweet_list, user_id}, _from, state) do
        databaseValue = getData(:newsfeed, user_id)
        tweet_list = Enum.reduce(databaseValue, [], fn(x, acc) ->
            username =  Enum.at(x,0)
            tweetid = Enum.at(x,1)
            tweet = getData(:user_tweets, username)
            acc = acc ++ [[username, tweetid, tweet[tweetid]]]
        end);
        {:reply, tweet_list, state}
    end

    def handle_call({:get_user_details, user_id}, _from, state) do
        result= []
        databaseValue = getData(:follower_list, user_id)
        result = result ++ [length(databaseValue)]
        databaseValue = getData(:following_list, user_id)
        result = result ++ [length(databaseValue)]
        tweet_map = getData(:user_tweets,user_id)
        value = if(tweet_map == []) do
            0
        else
            map_size(tweet_map)
        end

        result = result ++ [value]
        {:reply, result, state}
    end

    def handle_call({:create_group, user_id, groupname}, _from, state) do
        :ets.insert(:group_users,{groupname,[user_id]})
        :ets.insert(:group_messages,{groupname,[]})
        users_group_list = getData(:user_groups, user_id)
        users_group_list =  users_group_list ++ [groupname]
        :ets.insert(:user_groups,{user_id,users_group_list})
        {:reply, :ok, state}
    end

    def handle_call({:add_group_member, member_id, groupname}, _from, state) do
        users_list = getData(:group_users, groupname)
        users_list =  users_list ++ [member_id]
        :ets.insert(:group_users,{groupname,users_list})

        users_group_list = getData(:user_groups, member_id)
        users_group_list =  users_group_list ++ [groupname]
        :ets.insert(:user_groups,{member_id,users_group_list})
        {:reply, :ok, state}
    end

    def handle_call({:add_group_message, member_id, message, groupname}, _from, state) do
        group_message_list = getData(:group_messages, groupname)
        group_message_list =  group_message_list ++ [[member_id, message]]
        :ets.insert(:group_messages,{groupname,group_message_list})
        {:reply, :ok, state}
    end

    def handle_call({:get_user_groups, user_id}, _from, state) do
        databaseValue = getData(:user_groups, user_id)
        {:reply, databaseValue, state}
    end

    def handle_call({:get_group_messages, groupname}, _from, state) do
        databaseValue = getData(:group_messages, groupname)
        {:reply, databaseValue, state}
    end

    #---------------------------API--------------------------------#

    def check_registration_successfull(user_id,user_name,password) do
        databaseValue = getData(:user_details, user_id)
        if ([user_id,user_name,password] == databaseValue) do
            IO.puts "User #{user_id} is Registered successfully"
            true
        else
            IO.puts "User #{user_id} cannot be Registered"
            false
        end
    end

    def check_for_login(user_id) do
        if (getData(:active_users, user_id) == true) do
            IO.puts "User #{user_id} was logged in successfully"
            true
        else
            IO.puts "User #{user_id} is logged out"
            false
        end
    end

    def check_follower_successfull(user_id,follower_id) do
        databaseValue = getData(:follower_list, user_id)
        if (Enum.member?(databaseValue, follower_id)) do
            IO.puts "User #{user_id} is now following #{follower_id} "
            true
        else
            IO.puts "User #{user_id} is cannot be followed by #{follower_id}"
            false
        end
    end

    def check_tweet_successfull(user_id,message) do
        tweet_id = getData(:user_tweets, user_id) |> Enum.find(fn {key, val} -> val == message end) |> elem(0)
        followers_list = getData(:follower_list, user_id)
        receivedByAll = Enum.reduce(followers_list,[], fn(follower,received)-> 
            if(Enum.member?(getData(:newsfeed, follower), [user_id,tweet_id])) do
                received = received ++ [true]
            else
                received = received ++ [false]
            end
        end)
        if(Enum.member?(receivedByAll, false)) do
            IO.puts "Tweet #{message} not received by all the followers"
            false
        else
            IO.puts "Tweet #{message} received by all the followers"
            true
        end
    end

    def check_retweet_successfull(user_id,message) do
        tweet_id = getData(:user_tweets, user_id) |> Enum.find(fn {key, val} -> val == message end) |> elem(0)
        IO.inspect tweet_id, label: "tweet id"
        followers_list = getData(:follower_list, user_id)
        Enum.each(followers_list, fn(user_id)->
            #[{_id, message_list}] = :ets.lookup(:user_tweets,user_id)
            message_list = :ets.lookup(:newsfeed,user_id)
            IO.inspect message_list, label: "in news feed of "<>user_id
        end)
        receivedByAll = Enum.reduce(followers_list,[], fn(follower,received)-> 
            if(Enum.member?(getData(:newsfeed, follower), [user_id,tweet_id])) do
                received = received ++ [true]
            else
                received = received ++ [false]
            end
        end)
        if(Enum.member?(receivedByAll, false)) do
            IO.puts "Tweet \"#{message}\" not received by all the followers"
            false
        else
            IO.puts "Tweet \"#{message}\" received by all the followers"
            true
        end
    end

    def check_mention_successfull(user_id,message,mentioned_id) do
        tweet_id = getData(:user_tweets, user_id) |> Enum.find(fn {_key, val} -> val == message end) |> elem(0)
        if(Enum.member?(getData(:newsfeed, mentioned_id), [user_id,tweet_id])) do
            IO.puts "Tweet \"#{message}\" received by mentioned user #{mentioned_id}"
            true
        else
            IO.puts "Tweet \"#{message}\" not received by mentioned user #{mentioned_id}"
            false
        end
    end

    def check_hashtag_successfull(user_id,message,hashtag) do
        tweet_id = getData(:user_tweets, user_id) |> Enum.find(fn {_key, val} -> val == message end) |> elem(0)
        if(Enum.member?(getData(:hashtags, hashtag), [user_id,tweet_id])) do
            IO.puts "Hashtag #{hashtag} Stored Successfully"
            true
        else
            IO.puts "Hashtag #{hashtag} Not Stored "
            false
        end
    end

    def check_if_tweet_received(user_id,sender_id,message) do
        tweet_id = getData(:user_tweets, sender_id) |> Enum.find(fn {_key, val} -> val == message end) |> elem(0)
        if(Enum.member?(getData(:newsfeed, user_id), [sender_id,tweet_id])) do
            IO.puts "Tweet \"#{message}\" received by #{user_id}"
            true
        else
            IO.puts "Tweet \"#{message}\" not received by #{user_id}"
            false
        end
    end

    def check_hashtag(hashtag) do
        hashtag_list = (getData(:hashtags, hashtag))
        if(hashtag_list!=[]) do
            IO.inspect hashtag_list, label: "Hashtag #{hashtag} found in "
            true
        else
            IO.puts "Hashtag #{hashtag} not found"
            false
        end
    end

    def check_mentions(mentions) do
        mentions_list = (getData(:mentions, mentions))
        if(mentions_list!=[]) do
            IO.inspect mentions_list, label: mentions<>"found in "
            true
        else
            IO.puts mentions<>"not found in any message"
            false
        end
    end
end
