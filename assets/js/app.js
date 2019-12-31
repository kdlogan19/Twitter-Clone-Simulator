// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.css"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//
import "phoenix_html"
import Chart from 'chart.js'
// Import local files
//
// Local files can be imported directly using relative paths, for example:
import socket from "./socket"

// let loginbutton = document.getElementById("loginbutton");
let userchannel;
let groupchannel;
let init_fun;
var shajs = require('sha.js')
window.login = function(event){
    username = document.getElementById("username")
    password = document.getElementById("password")
    if(username.length!=0 && password.length!=0){
        userchannel = socket.channel(`message:${username.value}`, {});
        userchannel.join()
            .receive("ok", resp => { console.log("Joined successfully", resp) })
            .receive("error", resp => { console.log("Unable to join", resp) })
        userchannel.push('login', { 
            username: username.value,
            password: shajs('sha256').update(password.value).digest('hex')
        });
        check_login(userchannel);
    }
    // window.location.href = "./home";
 }

 window.register = function(event){
    var registration_userid = document.getElementById("registration_userid")
    var registration_username = document.getElementById("registration_username")
    var registration_password = document.getElementById("registration_password")
    if(registration_userid.length!=0 && registration_username.length!=0 && registration_password.length!=0){
        userchannel = socket.channel(`message:${registration_userid.value}`, {});
        userchannel.join()
            .receive("ok", resp => { console.log("Joined successfully", resp) })
            .receive("error", resp => { console.log("Unable to join", resp) })
        userchannel.push('register', { 
            userid: registration_userid.value,
            username: registration_username.value,
            password: shajs('sha256').update(registration_password.value).digest('hex')
        });
    }
    
    userchannel.on(`message:${registration_userid.value}:registeration_status`, function (payload) {
        if(payload.status == "success"){
            alert("Registration Successfull. Enjoy Twitter")
            window.location.href = "./home?username="+registration_username.value;
        }else{
            alert("User Id already taken. Please use a different User Id")
            registration_userid.value = ""
            registration_username.value = ""
            registration_password.value = ""
        }
    });
 }

 function check_login(userchannel){
    userchannel.on(`message:${username.value}:login_sucessfull`, function (payload) {
        console.log(payload);
        alert("logged In")
        window.location.href = "./home?username="+username.value;
    });

    userchannel.on(`message:${username.value}:login_failed`, function (payload) {
        alert("Invalid Username or Password. Please try again");
    });
}

window.logout = function() { 
    window.location.href = "./";
}

var url = new URL(window.location.href);
var username = url.searchParams.get("username");

if(username!=null){
    Initialize_Connection()
}

function Initialize_Connection() {
    var username_header = document.getElementById("username");
    username_header.innerText = username;
    userchannel = socket.channel(`message:${username}`, {});
    userchannel.join();
    get_follower();
    if(window.location.href.indexOf("home") > -1){
        get_tweets()
        get_user_details()
    }
    else if(window.location.href.indexOf("usermessage") > -1){
        get_user_groups()
    }
    
    
}

function get_user_details(){
    userchannel.push('get_user_details', {
        user: username
    });

    userchannel.on(`message:${username}:user_details`, function (payload) {
        var ctx = document.getElementById("myChart").getContext('2d');
        var myChart = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: ["Followers", "Following ", "Number of Tweets"],
            datasets: [{
            backgroundColor: [
                "#3498db",
                "#e74c3c",
                "#34495e"
            ],
            data: [payload.user_details[0], payload.user_details[1], payload.user_details[2]]
            }]
        }
        });
    });
}
 
window.tweet = function() { 
    let message = document.getElementById("tweetbox");
    if(message.value.length > 0){
        userchannel.push('tweet', { 
            message: message.value   
        });
        message.value = '';  
    }

    userchannel.on(`message:${username}:tweetsend`, function (payload) {
        alert("Tweet Send")
    });
    
}

window.getquery = function() { 
    let search = document.getElementById("searchbox");
    if(search.value.length > 0){
        if(search.value.includes("#")){
            userchannel.push('hashtag', { 
                searchquery: search.value   
            });
        }else if(search.value.includes("@")){
            userchannel.push('usermention', { 
                searchquery: search.value.substr(1)  
            });
        }
        search.value = '';  
    }

    userchannel.on(`message:${username}:hashtagresult`, function (payload) {
        let ul = document.getElementById("result-list");
        ul.innerHTML = '';
        if(payload.result_list.length == 0){
            var li = document.createElement("li"); // create new list item DOM element
            li.innerHTML =  '<b> No Result Found</b>'; // set li contents
            ul.insertBefore(li, ul.childNodes[0]);     
        }else{
            for(var tweet in payload.result_list) {
                var li = document.createElement("li"); // create new list item DOM element
                li.innerHTML =  '<b>' + payload.result_list[tweet][0] + ': </b>' + payload.result_list[tweet][1];// set li contents
                ul.insertBefore(li, ul.childNodes[0]);     
            }
        }
    });

    userchannel.on(`message:${username}:mentionsresult`, function (payload) {
        let ul = document.getElementById("result-list");
        ul.innerHTML = '';
        if(payload.result_list.length == 0){
            var li = document.createElement("li"); // create new list item DOM element
            li.innerHTML =  '<b> No Result Found</b>'; // set li contents
            ul.insertBefore(li, ul.childNodes[0]);     
        }else{
            for(var tweet in payload.result_list) {
                var li = document.createElement("li"); // create new list item DOM element
                li.innerHTML =  '<b>' + payload.result_list[tweet][0] + ': </b>' + payload.result_list[tweet][1];// set li contents
                ul.insertBefore(li, ul.childNodes[0]);     
            }
        }
    });
    
}

window.follow = function() { 
    let follow_id = document.getElementById("follow_id");
    if(follow_id.value.length > 0){
        userchannel.push('follow', { 
            follow_id: follow_id.value   
        });
        follow_id.value = '';  
    }

    userchannel.on(`message:${username}:follow_success`, function (payload) {
        alert("You are now following "+ payload.follower);
    });
}

window.homepage = function() { 
    window.location.href = "./home?username="+username;
}

window.searchquery = function() { 
    window.location.href = "./searchquery?username="+username;
}

window.usermessage = function() { 
    window.location.href = "./usermessage?username="+username;
}



function get_tweets(){
    userchannel.push('get_tweets', {
        user: username
    });

    userchannel.on(`message:${username}:tweet_list`, function (payload) {
        let ul = document.getElementById("tweet-list");
        for(var tweet in payload.tweet_list) {
            var li = document.createElement("li"); // create new list item DOM element
            if(payload.tweet_list[tweet][2].includes("Retweet")){
                var original_tweet_data = payload.tweet_list[tweet][2];
                var original_user = original_tweet_data.split(":")[1]
                var original_tweet_id = original_tweet_data.split(":")[3]
                var original_tweet = original_tweet_data.split(":")[5]
                li.innerHTML =  '<b> Retweeted by ' + payload.tweet_list[tweet][0] + ' : </b><br><b> ' + original_user+ '</b> : '+ original_tweet+ '<span id='+original_user+'#'+original_tweet_id+' style="cursor:pointer;color:blue;text-decoration:underline;float:right" onClick="window.retweet(this)" >Retweet</a>'; // set li contents
            }else{
                li.innerHTML =  '<b>' + payload.tweet_list[tweet][0] + ' : </b>' + payload.tweet_list[tweet][2] + '<span id='+payload.tweet_list[tweet][0]+'#'+payload.tweet_list[tweet][1]+' style="cursor:pointer;color:blue;text-decoration:underline;float:right" onClick="window.retweet(this)" >Retweet</a>'; // set li contents
            }
            ul.insertBefore(li, ul.childNodes[0]);     
        }
    });

    userchannel.on(`message:${username}:retweet_message`, function (payload) {
        var original_tweet_data = payload.tweet_list[0][2];
        var original_user = original_tweet_data.split(":")[1]
        var original_tweet_id = original_tweet_data.split(":")[3]
        var original_tweet = original_tweet_data.split(":")[5]
        let ul = document.getElementById("tweet-list");
        var li = document.createElement("li"); // create new list item DOM element
        li.innerHTML =  '<b> Retweeted by ' + payload.tweet_list[0][0] + ' : </b><br><b> ' + original_user+ '</b> : '+ original_tweet+ '<span id='+original_user+'#'+original_tweet_id+' style="cursor:pointer;color:blue;text-decoration:underline;float:right" onClick="window.retweet(this)" >Retweet</a>'; // set li contents
        ul.insertBefore(li, ul.childNodes[0]);     
        
    });
}



window.retweet = function(tweet){
    var tweet_data= tweet.id.split("#");
    userchannel.push('retweet', {
        of_user: tweet_data[0],
        tweet_id: tweet_data[1]
    });

    userchannel.on(`message:${username}:retweetsend`, function (payload) {
        alert("Retweet Send")
    });
}

window.creategroup = function(tweet){
    var groupname= creategroupname.value;
    if(groupname.length > 0){
        userchannel.push('creategroup', {
            groupname: groupname
        });
    }
    userchannel.on(`message:${username}:groupcreated`, function (payload) {
        alert("Group Created")
        get_user_groups()
    });

    creategroupname.value = ""
}

function get_user_groups(){
    userchannel.push('get_groups', {
        user: username
    });

    userchannel.on(`message:${username}:group_list`, function (payload) {
        let ul = document.getElementById("group-list");
        ul.innerHTML = '';
        for(var group in payload.group_list) {
            var li = document.createElement("li"); 
            li.innerHTML =  '<button class="button_blue" type="button" style="width:100%" id='+payload.group_list[group]+' onClick="window.openchat(this.id)">' + payload.group_list[group] + '</button>'; // set li contents
            ul.insertBefore(li, ul.childNodes[0]);     
        }
    });

    userchannel.on(`message:${username}:addgroup`, function (payload) {
        let ul = document.getElementById("group-list");
        var li = document.createElement("li"); 
        li.innerHTML =  '<button type="button" class="button_blue" style="width:100%" id='+payload.group_list[0]+' onClick="window.openchat(this.id)">' + payload.group_list[0] + '</button>'; // set li contents
        ul.insertBefore(li, ul.childNodes[0]);  
    });
}

window.openchat = function(groupname){
    this.document.getElementById("groupname").innerText = groupname;
    this.document.getElementById("chatwindow").style.display = "block"
    groupchannel = socket.channel(`message:${groupname}`, {});
    groupchannel.join();
    
    userchannel.push('get_group_messages', {
        user: username,
        group_name: groupname 
    });

    userchannel.on(`message:${username}:group_messages`, function (payload) {
        let ul = document.getElementById("message-list");
        ul.innerHTML = '';
        for(var message in payload.message_list) {
            var li = document.createElement("li"); // create new list item DOM element
            li.innerHTML =  '<b>' + payload.message_list[message][0] + ': </b><br>' + payload.message_list[message][1];// set li contents
            ul.appendChild(li);     
        }
    });

    groupchannel.on(`message:${groupname}:new_message`, function (payload) {
        
        let ul = document.getElementById("message-list");
        var li = document.createElement("li"); // create new list item DOM element
        li.innerHTML =  '<b>' + payload.message_list[0] + ': </b><br>' + payload.message_list[1];// set li contents
        ul.appendChild(li);               
    });
}

window.addmessage = function(){
    var message = document.getElementById("messagebox").value;
    var groupname = document.getElementById("groupname").innerText
    if(message.length > 0){
        groupchannel.push('add_group_messages', {
            username: username,
            group_name: groupname,
            messages: message
        });
    }
    document.getElementById("messagebox").value = ""
}


window.add_group_member = function(){

    userchannel.push('add_group_member', {
        member_id: document.getElementById("member_id").value,
        groupname: document.getElementById("groupname").innerText
    });
    this.alert(document.getElementById("member_id").value +" added to the group")
    document.getElementById("member_id").value = ""
    userchannel.on(`message:${username}:group_list`, function (payload) {
        let ul = document.getElementById("group-list");
        ul.innerHTML = '';
        for(var group in payload.group_list) {
            var li = document.createElement("li"); 
            li.innerHTML =  '<button type="button" style="align:center;width:100%" id='+payload.group_list[group]+' onClick="window.openchat(this.id)">' + payload.group_list[group] + '</button>'; // set li contents
            ul.insertBefore(li, ul.childNodes[0]);     
        }
    });

    
}


function get_follower(){
    userchannel.push('get_follower', {
        user: username
    });

    userchannel.on(`message:${username}:followers_list`, function (payload) {
        console.log(payload);
        let ul = document.getElementById("follower-list");
        ul.innerHTML = '';
        var followers_list = payload.followers_list.sort()
        for(var follower in followers_list) {
            let li = document.createElement("li"); // create new list item DOM element
            li.innerHTML =  payload.followers_list[follower]; // set li contents
            ul.appendChild(li);     
        }
    });

    userchannel.on(`message:${username}:update_follower_list`, function (payload) {
        alert(payload.follower + "is now following you");
        let ul = document.getElementById("follower-list");
        let li = document.createElement("li"); // create new list item DOM element
        li.innerHTML =  payload.follower; // set li contents
        ul.appendChild(li);     
    });
}

// channel.on('shout', function (payload) { // listen to the 'shout' event\\
//     let ul = document.getElementById('msg-list'); 
//     let li = document.createElement("li"); // create new list item DOM element
//     let name = payload.name || 'guest';    // get name from payload or set default
//     li.innerHTML = '<b>' + name + '</b>: ' + payload.message; // set li contents
//     ul.appendChild(li);                    // append to list
// });
       // list of messages
