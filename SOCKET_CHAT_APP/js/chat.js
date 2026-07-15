const baseURL = "https://tawreedat.nitg-eg.com/courier_apis/api/v1/courier";
const apiURL = baseURL + "/api/v1/courier";
const rawToken = localStorage.getItem("token") || "";
const token = rawToken.startsWith("Bearer") ? rawToken : `Bearer ${rawToken}`;

let currentChatId = null;
let currentChat = null;
let currentUserId = null;
let onlineUsers = new Set();

const headers = {
  "Content-Type": "application/json; charset=UTF-8",
  authorization: token,
};

// ====================== ioClient ======================
const ioClient = io(baseURL, {
  auth: { accessToken: token },
});

ioClient.on("connect", () => {
  console.log("Socket connected!");
  $("#onlineStatus")
    .text("Connected")
    .removeClass("bg-secondary bg-danger")
    .addClass("bg-success");
  refreshOnlineUsers();
});

ioClient.on("connect_error", (err) => {
  console.log("connect_error:", err.message);
  $("#onlineStatus")
    .text("Connection Error")
    .removeClass("bg-secondary bg-success")
    .addClass("bg-danger");
});

ioClient.on("disconnect", () => {
  $("#onlineStatus")
    .text("Disconnected")
    .removeClass("bg-secondary bg-success")
    .addClass("bg-danger");
});

// Listen globally for new messages
ioClient.on("chat:new_message", (data) => {
  console.log("New message received via socket:", data);
  const message = data.message;

  if (currentChatId === message.chat_id) {
    appendMessage(message, "friend");
    ioClient.emit("chat:read_messages", { chatId: currentChatId });
  } else {
    const audio = document.getElementById("notifyTone");
    if (audio) {
      audio.currentTime = 0;
      audio.play().catch((err) => console.log("Audio play blocked:", err));
    }
    loadInbox();
  }
});

// Listener for read receipts
ioClient.on("chat:message_read", (data) => {
  console.log("Messages marked as read by others:", data);
  if (currentChatId === data.chatId) {
    updateMessageReadStatus(data.readBy);
  }
});

// Typing indicators
ioClient.on("chat:user_typing", (data) => {
  if (currentChatId === data.chatId) {
    $("#typingIndicator")
      .text("User " + data.userId + " is typing...")
      .show();
  }
});

ioClient.on("chat:user_stopped_typing", (data) => {
  if (currentChatId === data.chatId) {
    $("#typingIndicator").hide();
  }
});

// User online/offline status
ioClient.on("user:online", (data) => {
  console.log("User online:", data.userId);
  onlineUsers.add(data.userId);
  refreshOnlineUsers();
  updateChatListOnlineStatus();
});

ioClient.on("user:offline", (data) => {
  console.log("User offline:", data.userId);
  onlineUsers.delete(data.userId);
  refreshOnlineUsers();
  updateChatListOnlineStatus();
});

// ====================== Init ======================
$(document).ready(() => {
  try {
    const payloadBase64 = token.split(".")[1];
    if (payloadBase64) {
      const decoded = JSON.parse(atob(payloadBase64));
      currentUserId = decoded.userId || decoded.id || decoded.sub;
      $("#profileImage").hide();
      $("#userName").text("My ID: " + currentUserId);
    }
  } catch (e) {
    console.log("Token decode error:", e);
  }

  // Typing event listeners
  $("#messageBody").on("input", function () {
    if (!currentChatId) return;
    if ($(this).val().length > 0) {
      ioClient.emit("chat:typing", { chatId: Number(currentChatId) });
    } else {
      ioClient.emit("chat:stop_typing", { chatId: Number(currentChatId) });
    }
  });

  // Enter key to send message
  $("#messageBody").on("keypress", function (e) {
    if (e.which === 13) {
      sendMessage();
    }
  });

  loadInbox();
});

// ====================== sendMessage ======================
function sendMessage() {
  if (!currentChatId) return alert("Select a chat first");

  const content = $("#messageBody").val();
  if (!content.trim()) return;

  const data = {
    content: content,
    type: "TEXT",
  };

  axios
    .post(`${apiURL}/chat/send-message/${currentChatId}`, data, { headers })
    .then((res) => {
      const message = res.data.data?.message || res.data.data;
      appendMessage(message, "me");
      $("#messageBody").val("");
      ioClient.emit("chat:stop_typing", { chatId: Number(currentChatId) });
      loadInbox();
    })
    .catch((err) => {
      console.error("Failed to send message:", err);
      alert(
        "Failed to send message: " +
          (err.response?.data?.message || err.message),
      );
    });
}

// ====================== Socket.IO Status Functions ======================
function refreshOnlineUsers() {
  ioClient.emit("users:get_online_users", (response) => {
    if (response.users) {
      onlineUsers = new Set(response.users);
      renderOnlineUsers();
      updateChatListOnlineStatus();
    }
  });
}

function getUserStatus(userId, callback) {
  ioClient.emit("user:get_status", { userId }, (response) => {
    callback(response);
  });
}

function renderOnlineUsers() {
  let html = "";
  if (onlineUsers.size === 0) {
    html = '<div class="text-muted small">No users online</div>';
  } else {
    onlineUsers.forEach((userId) => {
      if (userId !== currentUserId) {
        html += `<div class="d-flex align-items-center mb-1">
          <span class="badge bg-success rounded-circle" style="width:8px;height:8px;"></span>
          <span class="ms-2 small">User ${userId}</span>
        </div>`;
      }
    });
  }
  $("#onlineUsers").html(html);
}

// ====================== REST APIs ======================

function loadInbox() {
  axios
    .get(`${apiURL}/chat/get-my-chats`, { headers })
    .then((res) => {
      let result = res.data.data;
      let chats = result.myChats || result.chats || [];
      renderChatList(chats);
    })
    .catch((err) => {
      console.log("Error loading chats", err);
      const isUnauthorized =
        err.response?.status === 401 || err.response?.status === 403;
      if (isUnauthorized) {
        document.getElementById("chatUsers").innerHTML =
          "<div class='text-danger p-2'>Session expired. Please <a href='index.html'>login</a> again.</div>";
      } else {
        document.getElementById("chatUsers").innerHTML =
          "<div class='text-danger p-2'>Failed to load chats</div>";
      }
    });
}

function renderChatList(chats) {
  let html = "";
  if (chats.length === 0) {
    html =
      '<div class="text-muted small p-2">No chats yet. Start a new chat!</div>';
  }
  chats.forEach((chat) => {
    const otherParticipant = chat.participants?.find(
      (p) => p.id !== currentUserId,
    );
    const name = chat.is_group
      ? chat.name || "Unnamed Group"
      : otherParticipant?.full_name || otherParticipant?.id || "Unknown";
    const isOnline = otherParticipant && onlineUsers.has(otherParticipant.id);
    const onlineIndicator =
      !chat.is_group && isOnline
        ? '<span class="badge bg-success rounded-circle" style="width:8px;height:8px;display:inline-block;margin-right:5px;"></span>'
        : "";
    const groupIndicator = chat.is_group
      ? '<span class="badge bg-info ms-1">Group</span>'
      : "";

    html += `
      <div onclick="openChat(${chat.id})" class="chatUser my-2 p-2 border rounded" style="cursor:pointer; background: ${chat.id === currentChatId ? "#e9ecef" : "transparent"};" data-chat-id="${chat.id}">
        <div class="d-flex justify-content-between align-items-center">
          <strong>${onlineIndicator}${name}${groupIndicator}</strong>
        </div>
        <div style="font-size: 12px; color: gray;">${chat.is_group ? "Group chat" : "Private chat"}</div>
      </div>
    `;
  });
  document.getElementById("chatUsers").innerHTML = html;
}

function updateChatListOnlineStatus() {
  $(".chatUser").each(function () {
    const chatId = $(this).data("chat-id");
    // Would need to map chat to participant for this to work fully
  });
}

function openChat(chatId) {
  if (currentChatId && currentChatId !== chatId) {
    ioClient.emit("chat:leave", { chatId: currentChatId });
  }

  currentChatId = chatId;
  currentChat = null;
  $("#messageList").html("<div class='text-center p-3'>Loading...</div>");
  $("#chatActions").addClass("d-none");
  $("#addParticipantSection").addClass("d-none");
  $("#messageInputArea").addClass("d-none");

  axios
    .get(`${apiURL}/chat/get-chat/${chatId}`, { headers })
    .then((res) => {
      const data = res.data.data;
      const messages = data.messages || [];
      currentChat = data;

      // Update chat title
      const otherParticipant = data.participants?.find(
        (p) => p.id !== currentUserId,
      );
      const chatName = data.is_group
        ? data.name || "Unnamed Group"
        : otherParticipant?.full_name || "Private Chat";
      $("#chatTitle").text(chatName);

      // Show appropriate controls
      $("#chatActions").removeClass("d-none");
      $("#messageInputArea").removeClass("d-none");

      if (data.is_group) {
        $("#addParticipantSection").removeClass("d-none");
      }

      // Render messages
      $("#messageList").html("");
      if (messages.length === 0) {
        $("#messageList").html(
          "<div class='text-center p-3 text-muted'>Say Hi to start the conversation!</div>",
        );
      } else {
        // Sort messages by created_at ascending
        messages.sort(
          (a, b) => new Date(a.created_at) - new Date(b.created_at),
        );
        messages.forEach((msg) => {
          const owner = msg.sender?.id === currentUserId ? "me" : "friend";
          appendMessage(msg, owner);
        });
      }

      // Join the socket room
      ioClient.emit("chat:join", { chatId: Number(chatId) }, (response) => {
        console.log("Joined chat room", response);
      });

      // Mark messages as read
      ioClient.emit("chat:read_messages", { chatId: Number(chatId) });

      loadInbox();
      scrollToBottom();
    })
    .catch((err) => {
      console.log("Error opening chat", err);
      alert(
        "Error opening chat: " + (err.response?.data?.message || err.message),
      );
    });
}

// ====================== Create Chat ======================
function startNewChat() {
  const userId = $("#newChatUserId").val();
  if (!userId) return alert("Please enter a user ID");

  axios
    .post(`${apiURL}/chat/create-chat/${userId}`, {}, { headers })
    .then((res) => {
      const chat = res.data.data.chat;
      const created = res.data.data.created;
      if (chat) {
        $("#newChatUserId").val("");
        loadInbox();
        openChat(chat.id);
        if (created) {
          console.log("New chat created");
        } else {
          console.log("Existing chat opened");
        }
      }
    })
    .catch((err) => {
      console.error(err);
      alert(
        "Error creating chat: " + (err.response?.data?.message || err.message),
      );
    });
}

// ====================== Create Group ======================
function createGroup() {
  const name = $("#newGroupName").val().trim();
  const userIdsStr = $("#newGroupUserIds").val().trim();

  if (!name) return alert("Please enter a group name");
  if (!userIdsStr) return alert("Please enter at least one user ID");

  const userIds = userIdsStr
    .split(",")
    .map((id) => parseInt(id.trim()))
    .filter((id) => !isNaN(id));
  if (userIds.length === 0) return alert("Please enter valid user IDs");

  axios
    .post(`${apiURL}/chat/create-chat-group`, { name, userIds }, { headers })
    .then((res) => {
      const chat = res.data.data.chat;
      if (chat) {
        $("#newGroupName").val("");
        $("#newGroupUserIds").val("");
        loadInbox();
        openChat(chat.id);
      }
    })
    .catch((err) => {
      console.error(err);
      alert(
        "Error creating group: " + (err.response?.data?.message || err.message),
      );
    });
}

// ====================== Add Participant ======================
function addParticipant() {
  if (!currentChatId) return alert("Select a chat first");

  const userId = $("#newParticipantId").val();
  if (!userId) return alert("Please enter a user ID");

  axios
    .post(
      `${apiURL}/chat/add-participant/${currentChatId}`,
      { userId: parseInt(userId) },
      { headers },
    )
    .then((res) => {
      $("#newParticipantId").val("");
      alert("Participant added successfully!");
      openChat(currentChatId); // Refresh chat
    })
    .catch((err) => {
      console.error(err);
      alert(
        "Error adding participant: " +
          (err.response?.data?.message || err.message),
      );
    });
}

// ====================== Leave Chat ======================
function leaveCurrentChat() {
  if (!currentChatId) return;

  if (!confirm("Are you sure you want to leave this chat?")) return;

  axios
    .delete(`${apiURL}/chat/leave-chat/${currentChatId}`, { headers })
    .then((res) => {
      ioClient.emit("chat:leave", { chatId: currentChatId });
      currentChatId = null;
      currentChat = null;
      $("#messageList").html(
        "<div class='text-center p-3 text-muted'>Select a chat to start messaging</div>",
      );
      $("#chatTitle").text("Select a chat");
      $("#chatActions").addClass("d-none");
      $("#addParticipantSection").addClass("d-none");
      $("#messageInputArea").addClass("d-none");
      loadInbox();
    })
    .catch((err) => {
      console.error(err);
      alert(
        "Error leaving chat: " + (err.response?.data?.message || err.message),
      );
    });
}

// ====================== Delete Message ======================
function deleteMessage(messageId) {
  if (!confirm("Are you sure you want to delete this message?")) return;

  axios
    .delete(`${apiURL}/chat/delete-message/${messageId}`, { headers })
    .then((res) => {
      $(`#message-${messageId}`).remove();
    })
    .catch((err) => {
      console.error(err);
      alert(
        "Error deleting message: " +
          (err.response?.data?.message || err.message),
      );
    });
}

// ====================== Helpers ======================
function appendMessage(msg, owner) {
  const isMe = owner === "me";
  const isRead = msg.is_read;
  const readAt = msg.read_at;
  const status = isRead ? "✓✓" : "✓";
  const statusColor = isRead ? "#34b7f1" : "#999";
  const statusHtml = isMe
    ? `<span class="read-status" data-message-id="${msg.id}" style="font-size:10px; color:${statusColor}">${status}</span>`
    : "";

  const deleteHtml = isMe
    ? `<button onclick="deleteMessage(${msg.id})" class="btn btn-link btn-sm text-danger" style="font-size:10px; padding:0; margin-left:5px;">×</button>`
    : "";

  const div = document.createElement("div");
  div.id = `message-${msg.id}`;
  div.className = isMe ? "me text-end p-2" : "myFriend p-2 text-start";
  div.innerHTML = `
    <div style="background: ${isMe ? "#dcf8c6" : "#fff"}; display: inline-block; padding: 8px 12px; border-radius: 10px; border: 1px solid #ddd; max-width: 80%; text-align: left;">
      <div style="font-size:10px; font-weight:bold; color:gray; margin-bottom:3px;">${isMe ? "Me" : msg.sender?.full_name || msg.sender?.id || "User"}</div>
      <div>${escapeHtml(msg.content)}</div>
      <div style="font-size:9px; color:#999; margin-top:3px; text-align:right;">
        ${formatTime(msg.created_at)}
        ${statusHtml}
        ${deleteHtml}
      </div>
    </div>
  `;
  document.getElementById("messageList").appendChild(div);
  scrollToBottom();
}

function updateMessageReadStatus(readBy) {
  $(`.read-status`).each(function () {
    $(this).text("✓✓").css("color", "#34b7f1");
  });
}

function scrollToBottom() {
  const list = document.getElementById("messageList");
  if (list) {
    list.scrollTop = list.scrollHeight;
  }
}

function escapeHtml(text) {
  if (!text) return "";
  const div = document.createElement("div");
  div.textContent = text;
  return div.innerHTML;
}

function formatTime(timestamp) {
  if (!timestamp) return "";
  const date = new Date(timestamp);
  return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

// Make functions globally accessible for HTML onclick handlers
window.startNewChat = startNewChat;
window.createGroup = createGroup;
window.addParticipant = addParticipant;
window.leaveCurrentChat = leaveCurrentChat;
window.deleteMessage = deleteMessage;
window.openChat = openChat;
window.sendMessage = sendMessage;
window.refreshOnlineUsers = refreshOnlineUsers;
