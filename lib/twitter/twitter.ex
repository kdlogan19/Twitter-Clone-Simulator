defmodule TwitterSimulator do

    @message_list ["This is a simple message", "This is a message having hashtag # but without any mention","This is a message without hashtag but with user mention @","This is a message having hashtag # and user mention @"]
    @hashtag_list ["#COP5375","#DOS","#UFL","#Gainesville"]

    def start() do
        GenServer.start_link(__MODULE__, [], name: :twitter)
    end

    def init(state) do
        Registry.start_link(keys: :unique, name: :registry)
        TwitterEngine.start()
        {:ok, state}
    end

    def create_network(num_user, num_msg) do
        IO.inspect num_user, label: "Creating network"
        users_list = Enum.to_list(1..num_user) |> Enum.map(fn(user)-> "User-"<>Integer.to_string(user) end)
        Enum.each(users_list, fn(user_id) -> 
            {:ok, pid} = User.start(user_id)
            GenServer.call(pid, {:create_account, user_id,user_id,user_id})
        end)

        start_time = System.system_time(:millisecond)
        create_follower_list(num_user,users_list) 
        time_difference = System.system_time(:millisecond) - start_time
        IO.inspect time_difference, label: "Total time taken to generate all followers"

        start_time = System.system_time(:millisecond)
        Enum.each(1..num_msg, fn(count)->
            start_sending_message(users_list,num_user)    
        end)

        time_difference = System.system_time(:millisecond) - start_time
        #To Check the correctness
        #print_followers_list(users_list)
        #print_tweet_list(users_list)
        #print_hashtag_list()
        #print_mentions_list(users_list)
        #last_user = Enum.at(users_list,-1)
        #GenServer.call(get_pid(last_user),{:print_news_feed})
        #GenServer.call(get_pid(last_user),{:retweet})
        #print_tweet_list(users_list)
        #print_pending_tweets_list(users_list)
        #GenServer.call(get_pid(first_user),{:login,first_user,first_user})
        #GenServer.call(get_pid(first_user),{:query_hashtags})
        #GenServer.call(get_pid(first_user),{:query_mymentions})
        #GenServer.call(get_pid(last_user),{:delete_account, last_user})
        IO.puts "All message delivered"
        IO.inspect time_difference, label: "Total time taken to send all tweets in milliseconds"
        Process.sleep(1000)
        users_list
    end

    def generate_follower_list(users_list, category_user_list, followers_number) do
        Enum.each(category_user_list, fn(user_id) -> 
            no_of_followers = Enum.random(followers_number)
            followers_list = Enum.take_random(users_list--[user_id], no_of_followers)
            Enum.each(followers_list, fn(follower_id) ->
                GenServer.cast(get_pid(user_id),{:follow, follower_id})
            end)
        end)
    end

    def create_follower_list(num_user,users_list) do
        #Add followers
        #category1 are the 5% of user who has large followers.
        #category2 are the 30% of user who has moderate followers.
        #category3 are the 50% of user who has moderate to less followers
        #category4 are the 15% of user who has less followers
        temp_users_list = users_list
        percent_of_category1_user = floor((num_user/100)*5)
        percent_of_category2_user = floor((num_user/100)*30)
        percent_of_category3_user = floor((num_user/100)*50)
        percent_of_category4_user = floor((num_user/100)*15)
        category1_user_list = Enum.take_random(temp_users_list,percent_of_category1_user)
        temp_users_list = temp_users_list -- category1_user_list
        category2_user_list = Enum.take_random(temp_users_list,percent_of_category2_user)
        temp_users_list = temp_users_list -- category2_user_list
        category3_user_list = Enum.take_random(temp_users_list,percent_of_category3_user)
        temp_users_list = temp_users_list -- category3_user_list
        category4_user_list = Enum.take_random(temp_users_list,percent_of_category4_user)

        generate_follower_list(users_list, category1_user_list,floor(num_user*0.7)..floor(num_user*0.9))
        generate_follower_list(users_list, category2_user_list,floor(num_user*0.5)..floor(num_user*0.7))
        generate_follower_list(users_list, category3_user_list,floor(num_user*0.2)..floor(num_user*0.5))
        generate_follower_list(users_list, category4_user_list,floor(num_user*0.05)..floor(num_user*0.2))
    end

    def start_sending_message(users_list,num_user) do
        Enum.each(users_list, fn(user_id)->
            message = Enum.random(@message_list) 
                    |> String.replace("#",Enum.random(@hashtag_list)) 
                    |> String.replace("@","@"<>Enum.random(users_list--[user_id]))
            GenServer.cast(get_pid(user_id),{:tweet_msg,message})
        end)
    end

    def print_tweet_list(users_list) do
        IO.puts "-----------------Messages sent---------------"
        Enum.each(users_list, fn(user_id)->
            #[{_id, message_list}] = :ets.lookup(:user_tweets,user_id)
            message_list = :ets.lookup(:user_tweets,user_id)
            IO.inspect message_list, label: user_id
        end)
    end

    def print_followers_list(users_list) do
        IO.puts "-----------------Followers List---------------"
        Enum.each(users_list, fn(user_id)->
            IO.inspect :ets.lookup(:follower_list,user_id)
        end)
        
        IO.puts "-----------------Following List---------------"
        Enum.each(users_list, fn(user_id)->
            IO.inspect :ets.lookup(:following_list,user_id)
        end)

    end

    def print_hashtag_list() do
        IO.puts "-----------------Hashtags---------------"
        Enum.each( ["#COP5375","#DOS","#UFL","#Gainesville"], fn(hash_tag)->
            #[{user_id,message_list}] = :ets.lookup(:hashtags,hash_tag)
            message_list = :ets.lookup(:hashtags,hash_tag)
            IO.inspect message_list
        end)
    end
    
    def print_mentions_list(users_list) do
        IO.puts "-----------------Mentions---------------"
        Enum.each( users_list, fn(mention_id)->
            message_list = :ets.lookup(:mentions,mention_id)
            IO.inspect message_list, label: mention_id
        end)
    end

    def print_active_users_list(users_list) do
        IO.puts "-----------------Active Users---------------"
        Enum.each( users_list, fn(user_id)->
            [{_id, isActive}] = :ets.lookup(:active_users,user_id)
            IO.inspect isActive, label: user_id
        end)
    end

    def print_pending_tweets_list(users_list) do
        IO.puts "-----------------Pending Tweets---------------"
        Enum.each( users_list, fn(user_id)->
            message_list = :ets.lookup(:undelivered_tweets,user_id)
            IO.inspect message_list, label: user_id
        end)
    end

    def get_pid(user_handle) do
        case Registry.lookup(:registry, user_handle) do
            [{pid, _}] -> pid
            [] -> nil
        end
    end

    def handle_call({:display,total_count},_from,state) do
        testPerformance(total_count)
        {:reply,:ok, state}
    end

    def testPerformance(total_count) when total_count == 0 do
        IO.inspect "Complete"
    end

    def testPerformance(total_count) do
        receive do
            {:performance, num_follower, time} ->
                 IO.inspect time, label: num_follower
        end
        testPerformance(total_count-1)
    end
end
