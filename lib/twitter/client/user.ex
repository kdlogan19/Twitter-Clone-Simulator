defmodule User do
    @hashtag_list ["#COP5375","#DOS","#UFL","#Gainesville"]
    def start(user_handle) do
        GenServer.start_link(__MODULE__, [], name: {:via, Registry, {:registry, user_handle}})
    end

    def init(state) do
        {:ok, state}
    end

    def handle_call({:create_account, user_id, user_name, password}, _from, news_feed) do
        password = :crypto.hash(:sha256,password) |> Base.encode16() |> String.downcase()
        GenServer.call(:twitter_engine, {:register_user, user_id, user_name,password})
        {:reply, :ok, news_feed}
    end

    def handle_call({:delete_account, user_id}, _from, news_feed) do
        GenServer.call(:twitter_engine, {:delete_user, user_id})
        GenServer.call(:twitter_engine, {:logout_user, user_id})
        {:reply, :ok, news_feed}
    end

    def handle_call({:login, user_id, password}, _from, news_feed) do
        GenServer.call(:twitter_engine, {:login_user, user_id,password})
        {:reply, :ok, news_feed}
    end

    def handle_call({:logout}, _from, news_feed) do
        [my_user_id] = Registry.keys(:registry, self())
        GenServer.call(:twitter_engine, {:logout_user, my_user_id})
        {:reply, :ok, news_feed}
    end

    def handle_cast({:follow, follow_id}, news_feed) do
        [my_user_id] = Registry.keys(:registry, self())
        GenServer.cast(:twitter_engine, {:user_followers, my_user_id, follow_id})
        {:noreply, news_feed}
    end

    def handle_cast({:tweet_msg,message},news_feed)do
        [my_user_id] = Registry.keys(:registry, self())
        GenServer.cast(:twitter_engine, {:tweet_message,message, my_user_id})
        {:noreply, news_feed}
    end

    def handle_cast({:news_feed,from_user_id,tweet_id, message},news_feed)do
        [my_user_id] = Registry.keys(:registry, self())
        #IO.puts "#{my_user_id} : Message received from #{from_user_id}: - #{message}"
        news_feed = news_feed ++ [[from_user_id, tweet_id,message]]
        {:noreply, news_feed}
    end

    def handle_cast({:retweet_message,from_user_id,tweet_id, message},news_feed) do
        [my_user_id] = Registry.keys(:registry, self())
        retweeted_message_from = from_user_id
        originally_from = Regex.split(~r{:}, message) |> Enum.at(1)
        originally_tweet = Regex.split(~r{:}, message) |> Enum.at(3)
        #IO.inspect retweeted_message_from, label: "Retweet By"
        #IO.inspect originally_from, label: "Originaly From"
        #IO.inspect originally_tweet, label: "Originaly Tweet"
        news_feed = news_feed ++ [[from_user_id, tweet_id,message]]
        {:noreply, news_feed}
    end

    def handle_call({:retweet},_from,news_feed)do
        [my_user_id] = Registry.keys(:registry, self())
        tweet_data = 
        if(news_feed!=[]) do
            Enum.random(news_feed)
        else
            []   
        end
        retweet_msg = "Retweet:"<>Enum.at(tweet_data,0)<>":tweet:"<>Enum.at(tweet_data,2)
        #IO.inspect retweet_msg, label: "random retweeting message from "
        if(tweet_data!=[]) do
            GenServer.cast(:twitter_engine, {:retweet_message, my_user_id, Enum.at(tweet_data,0), Enum.at(tweet_data,1)}) 
        end
        {:reply,retweet_msg, news_feed}
    end

    def handle_call({:query_hashtags},_from, news_feed) do
        hashtag = Enum.random(@hashtag_list)
        hashtag_messages = GenServer.call(:twitter_engine, {:get_messages_with_hashtags, hashtag})
        if(hashtag_messages!=[]) do
            IO.inspect hashtag_messages, label: "\n\nMessage Found for "<>hashtag<>"\n"
        else
            IO.puts "No Message found for "<>hashtag
        end
        {:reply,:ok, news_feed}
    end
    
    def handle_call({:query_mymentions},_from, news_feed) do
        [my_user_id] = Registry.keys(:registry, self())
        mentioned_messages = GenServer.call(:twitter_engine, {:get_messages_with_mentions, my_user_id})
        if(mentioned_messages!=[]) do
            IO.inspect mentioned_messages, label: "\n\nMessage Found for Mention ID - "<>my_user_id<>"\n"
        else
            IO.puts "No Message found for Mention ID - "<>my_user_id
        end
        {:reply,:ok, news_feed}
    end

    def handle_call({:print_news_feed},_from,news_feed) do
        if(news_feed != []) do
            IO.inspect news_feed, label: "News Feed"
        else
            IO.inspect "No messages in the News Feed"
        end
        {:reply, :ok, news_feed}
    end
end