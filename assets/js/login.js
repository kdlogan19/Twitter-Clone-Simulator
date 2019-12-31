import socket from "./socket"

let channel = socket.channel('message:lobby', {});
channel.join(); 

let tweetbutton = document.getElementById("tweetbutton");
tweetbutton.addEventListener("click", function(event){
    let message = document.getElementById("tweetbox");
    
    if(message.value.length > 0){
        channel.push('shout', { 
            message: message.value   
        });
        message.value = '';  
    }
 });

channel.on('shout', function (payload) { // listen to the 'shout' event\\
    alert("hello");
    let li = document.createElement("li"); // create new list item DOM element
    let name = payload.name || 'guest';    // get name from payload or set default
    li.innerHTML = '<b>' + name + '</b>: ' + payload.message; // set li contents
    ul.appendChild(li);                    // append to list
});

let ul = document.getElementById('msg-list');        // list of messages.