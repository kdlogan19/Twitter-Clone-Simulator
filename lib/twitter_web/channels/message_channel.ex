defmodule TwitterWeb.MessageChannel do
  use TwitterWeb, :channel
  require Logger
  def join("message:"<>username, payload, socket) do
    if authorized?(payload) do
      {:ok, %{channel: "message:#{username}"}, assign(socket, :user_id, username)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end
  
  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (message:lobby).
  def handle_in("shout", payload, socket) do
    IO.inspect ":: Shout receive a message!::"
    broadcast socket, "shout", payload
    {:noreply, socket}
  end

  def handle_in("login", payload, socket) do
    status = GenServer.call(:twitter_engine,{:login_user,payload["username"],payload["password"]})
    if(status == :success) do
      broadcast!(socket, "message:#{payload["username"]}:login_sucessfull",payload)
      IO.inspect "Logged IN"
      #broadcast socket, "login_successfull", payload
    else 
      broadcast!(socket, "message:#{payload["username"]}:login_failed",payload)
    end
    #broadcast socket, "shout", payload
    {:noreply, socket}
  end

  def handle_in("register", payload, socket) do
    user_id = payload["userid"]
    status = GenServer.call(:twitter_engine,{:register_user,payload["userid"],payload["username"],payload["password"]})
    IO.inspect status, label: "registration status"
    if(status == :success) do
      payload = %{:status =>"success" }
      broadcast!(socket, "message:#{user_id}:registeration_status",payload)
    else 
      payload = %{:status =>"failed" }
      broadcast!(socket, "message:#{user_id}:registeration_status",payload)
    end
    #broadcast socket, "shout", payload
    {:noreply, socket}
  end

  def handle_in("tweet", payload, socket) do
    user_id = socket.assigns[:user_id]
    GenServer.cast(:twitter_engine,{:tweet_message,payload["message"],user_id})
    broadcast!(socket, "message:#{user_id}:tweetsend",payload)
    {:noreply, socket}
  end

  def handle_in("retweet", payload, socket) do
    user_id = socket.assigns[:user_id]
    GenServer.cast(:twitter_engine,{:retweet_message,user_id, payload["of_user"],payload["tweet_id"]})
    broadcast!(socket, "message:#{user_id}:retweetsend",payload)
    {:noreply, socket}
  end

  def handle_in("creategroup", payload, socket) do
    user_id = socket.assigns[:user_id]
    GenServer.call(:twitter_engine,{:create_group,user_id, payload["groupname"]})
    broadcast!(socket, "message:#{user_id}:groupcreated",payload)
    {:noreply, socket}
  end

  def handle_in("get_follower", payload, socket) do
    user_id = socket.assigns[:user_id]
    followers_list = GenServer.call(:twitter_engine,{:get_followers_list,user_id})
    payload = %{:followers_list =>followers_list }
    broadcast!(socket, "message:#{user_id}:followers_list",payload)
    {:noreply, socket}
  end

  def handle_in("get_tweets", payload, socket) do
    user_id = socket.assigns[:user_id]
    tweet_list = GenServer.call(:twitter_engine,{:get_tweet_list,user_id})
    payload = %{:tweet_list =>tweet_list }
    broadcast!(socket, "message:#{user_id}:tweet_list",payload)
    {:noreply, socket}
  end

  def handle_in("get_groups", payload, socket) do
    user_id = socket.assigns[:user_id]
    group_list = GenServer.call(:twitter_engine,{:get_user_groups,user_id})
    payload = %{:group_list =>group_list }
    broadcast!(socket, "message:#{user_id}:group_list",payload)
    {:noreply, socket}
  end

  def handle_in("add_group_member", payload, socket) do
    user_id = socket.assigns[:user_id]
    member_id = payload["member_id"]
    GenServer.call(:twitter_engine,{:add_group_member,member_id,payload["groupname"]})
    payload = %{:group_list =>[payload["groupname"]] }
    TwitterWeb.Endpoint.broadcast!("message:#{member_id}", "message:#{member_id}:addgroup", payload)
    {:noreply, socket}
  end

  def handle_in("hashtag", payload, socket) do
    user_id = socket.assigns[:user_id]
    result_list = GenServer.call(:twitter_engine,{:get_messages_with_hashtags,payload["searchquery"]})
    payload = %{:result_list =>result_list }
    broadcast!(socket, "message:#{user_id}:hashtagresult",payload)
    {:noreply, socket}
  end

  def handle_in("usermention", payload, socket) do
    user_id = socket.assigns[:user_id]
    result_list = GenServer.call(:twitter_engine,{:get_messages_with_mentions,payload["searchquery"]})
    payload = %{:result_list =>result_list }
    broadcast!(socket, "message:#{user_id}:mentionsresult",payload)
    {:noreply, socket}
  end

  def handle_in("follow", payload, socket) do
    user_id = socket.assigns[:user_id]
    follow_to = payload["follow_id"]
    result_list = GenServer.cast(:twitter_engine,{:user_followers,user_id, follow_to})
    payload = %{:follower =>user_id }
    TwitterWeb.Endpoint.broadcast!("message:#{follow_to}", "message:#{follow_to}:update_follower_list", payload)
    payload = %{:follower =>follow_to }
    broadcast!(socket, "message:#{user_id}:follow_success",payload)
    {:noreply, socket}
  end

  def handle_in("get_group_messages", payload, socket) do
    user_id = socket.assigns[:user_id]
    message_list = GenServer.call(:twitter_engine,{:get_group_messages, payload["group_name"]})
    payload = %{:message_list =>message_list }
    broadcast!(socket, "message:#{user_id}:group_messages",payload)
    {:noreply, socket}
  end

  def handle_in("add_group_messages", payload, socket) do
    group_name = payload["group_name"]
    GenServer.call(:twitter_engine,{:add_group_message,payload["username"], payload["messages"], payload["group_name"]})
    payload = %{:message_list => [payload["username"],payload["messages"],payload["group_name"]] }
    IO.inspect payload, label: "payload"
    broadcast!(socket, "message:#{group_name}:new_message",payload)
    {:noreply, socket}
  end

  def handle_in("get_user_details", payload, socket) do
    user_id = socket.assigns[:user_id]
    user_details = GenServer.call(:twitter_engine,{:get_user_details,user_id})
    payload = %{:user_details =>user_details }
    broadcast!(socket, "message:#{user_id}:user_details",payload)
    {:noreply, socket}
  end
  
  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end

  def distributeTweet(user_id, tweetId, tweet, followers_list) do
    #IO.inspect user_id<>" "<>tweetId<>" "<>tweet<>" "<>followers_list, label: "sending"
    payload = %{:tweet_list => [[user_id, tweetId, tweet]]}
    Enum.each(followers_list, fn(follower) -> 
      TwitterWeb.Endpoint.broadcast!("message:#{follower}", "message:#{follower}:tweet_list", payload)
    end)
  end

  def distributeRetweet(user_id, tweetId, tweet, followers_list) do
    #IO.inspect user_id<>" "<>tweetId<>" "<>tweet<>" "<>followers_list, label: "sending"
    payload = %{:tweet_list => [[user_id, tweetId, tweet]]}
    Enum.each(followers_list, fn(follower) -> 
      TwitterWeb.Endpoint.broadcast!("message:#{follower}", "message:#{follower}:retweet_message", payload)
    end)
  end
end
