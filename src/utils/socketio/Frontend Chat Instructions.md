Here is the complete step-by-step guide for the Frontend developer. It covers exactly what APIs to call and what Socket events to emit/listen for in every scenario:

---

### Scenario 1: Initializing the App (Global Setup)

When the user opens the application and logs in:

1. **Frontend:** Connects to the Socket server with the JWT token.
2. **Frontend:** Calls API `GET /chat/get-my-chats` to load the inbox (list of all chats, last messages, and unread counts).
3. **Frontend:** Listens to `chat:new_message` globally (to update the inbox unread count or show a push notification if the user receives a message while not inside that specific chat screen).

---

### Scenario 2: Starting a NEW Private Chat

When the user clicks "Message" on another user's profile:

1. **Frontend:** Calls API `POST /chat/create-chat/:userId` (passing the other user's ID).
   - If the chat already exists, the API returns the existing `chat` object (`created: false`).
   - If it's new, the API creates it and returns the `chat` object (`created: true`).
2. **Frontend:** Receives `chatId` from the API response.
3. **Frontend:** Emits Socket event `chat:join` with `{ chatId }` to join the real-time room.
4. **Frontend:** Opens the chat screen for that `chatId`.

---

### Scenario 3: Opening an EXISTING Chat

When the user clicks on an existing chat from their Inbox list:

1. **Frontend:** Calls API `GET /chat/get-chat/:chatId`.
   - The backend automatically marks all unread messages in this chat as "read".
   - The backend returns the full chat history (paginated).
2. **Frontend:** Emits Socket event `chat:join` with `{ chatId }`.
   - Now the user is ready to send and receive real-time messages.
3. **Frontend:** (Optional but recommended) Emits Socket event `chat:read_messages` with `{ chatId }` to tell the sender "I have opened the chat and read your previous messages".

---

### Scenario 4: Sending a Message (Text)

While inside an open chat:

1. **Frontend:** User types a message and hits send.
2. **Frontend:** Calls API `POST /chat/send-message/:chatId` with `{ content, type: "TEXT" }` (multipart/form-data).
3. **Backend:** Saves the message to database and emits `chat:new_message` to everyone else in the room.
4. **Frontend (Sender):** Receives the saved message in the API response and instantly adds it to their own screen.

---

### Scenario 4b: Sending a Message (File/Image/Voice)

While inside an open chat:

1. **Frontend:** User selects a file/image or records a voice message.
2. **Frontend:** Calls API `POST /chat/send-message/:chatId` with:
   - `file`: The file (multipart/form-data field name is "file")
   - `type`: One of `"IMAGE"`, `"FILE"`, or `"VOICE"` (optional - backend will auto-detect if not provided)
   - `content`: Optional text description
3. **Backend:** Uploads the file to Cloudinary, saves the message with the file URL, and emits `chat:new_message` to everyone else in the room.
4. **Frontend (Sender):** Receives the saved message in the API response and instantly adds it to their own screen.

---

### Scenario 5: Receiving a Message (While inside the chat)

1. **Frontend:** User is staring at the chat screen (already joined the room).
2. **Frontend:** Listens to Socket event `chat:new_message`.
3. **Frontend:** Checks if the incoming message's `chat_id` matches the currently open chat.
   - If it matches: Append the message to the scrollable screen.
   - Instantly emit `chat:read_messages` with `{ chatId }` so the sender gets a blue tick ✅✅ since you are actively looking at it.
4. **Frontend (Sender):** Listen to `chat:message_read` event to know when your messages have been read by others.
   - The event payload includes: `{ chatId, readBy, read_at }`
   - Update the message UI to show double blue ticks ✅✅ for messages read by the recipient.

---

### Scenario 6: Receiving a Message (While OUTSIDE the chat)

1. **Frontend:** User is on the Home screen or Inbox list.
2. **Frontend:** Listens to Socket event `chat:new_message`.
3. **Frontend:** Checks if the incoming message's `chat_id` matches the currently open chat.
   - It doesn't match (because no chat is open).
   - Increment the "Unread Count" badge for that chat in the Inbox list.
   - Do **not** emit `chat:read_messages` (because the user hasn't seen it yet).

---

### Scenario 7: Typing Indicators

When the user is typing:

1. **Frontend:** On keystroke, emit `chat:typing` with `{ chatId }`.
   - (Best practice: debounce this so it doesn't emit 100 times a second).
2. **Other Users:** Listen to `chat:user_typing` and display _"Ahmed is typing..."_
3. **Frontend:** When the user stops typing (or sends the message), emit `chat:stop_typing` with `{ chatId }`.
4. **Other Users:** Listen to `chat:user_stopped_typing` and hide the indicator.

---

### Scenario 8: Creating a Group Chat

1. **Frontend:** User selects multiple users and chooses a group name.
2. **Frontend:** Calls API `POST /chat/create-chat-group` with `{ name, userIds: [1, 2, 3] }`.
3. **Frontend:** Receives the new `chatId`.
4. **Frontend:** Emits `chat:join` with `{ chatId }` to start chatting.

---

### Scenario 9: Leaving a Chat (Closing the screen)

When the user presses the 'Back' button to leave the chat screen and go back to the Inbox:

1. **Frontend:** Emits Socket event `chat:leave` with `{ chatId }`.
   - This stops the socket from receiving events for that specific chat while they are browsing other parts of the app.

---

### Scenario 10: Adding a Participant to a Group Chat

When the user wants to add someone to an existing group chat:

1. **Frontend:** Calls API `POST /chat/add-participant/:chatId` with `{ userId: number }`.
2. **Backend:** Verifies the current user is a member of the group and adds the new participant.
   - If the user was previously in the chat and left, they will be re-added.
   - If the user is already an active participant, returns an error.
3. **Frontend:** Updates the group participants list in the UI.

---

### Scenario 11: Deleting a Message

When the user wants to delete their own message:

1. **Frontend:** Calls API `DELETE /chat/delete-message/:messageId`.
2. **Backend:** Verifies the message belongs to the current user and performs a soft delete.
3. **Frontend:** Removes the message from the UI (or shows "This message was deleted" placeholder).

---

### Scenario 12: Permanently Leaving a Chat

When the user wants to permanently leave a group or private chat:

1. **Frontend:** Calls API `DELETE /chat/leave-chat/:chatId`.
2. **Backend:** Marks the user as having left the chat (sets `left_at` timestamp).
3. **Frontend:** Emits Socket event `chat:leave` with `{ chatId }`.
4. **Frontend:** Removes the chat from the inbox or marks it as "Left".
5. **Frontend:** Navigates back to the Inbox screen.
