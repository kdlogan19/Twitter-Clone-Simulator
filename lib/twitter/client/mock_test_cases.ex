defmodule MockTestCases do

  @num_user 10
    def mock_registration(user_id, user_name,password) do
        GenServer.call(:twitter_engine, {:register_user, user_id, user_name,password} )
    end

    def mock_follower(user_id, user_name,password,follower_id) do
      {:ok, pid} = User.start(user_id)
      GenServer.call(pid, {:create_account, user_id,user_name,password})
      #TwitterEngine.check_registration_successfull(user_id,user_name,password)
      GenServer.cast(pid,{:follow, follower_id})
  end

  def mock_send_tweets(user_id, message) do
    GenServer.cast(Twitter.get_pid(user_id),{:tweet_msg,message})
  end

  def mock_retweets(user_id) do
    message_tweet = GenServer.call(Twitter.get_pid(user_id),{:retweet})
    message_tweet
  end

  def mock_logout(user_id) do
    message_tweet = GenServer.call(Twitter.get_pid(user_id),{:logout})
  end

  def mock_login(user_id,password) do
    message_tweet = GenServer.call(Twitter.get_pid(user_id),{:login, user_id,password})
  end

end