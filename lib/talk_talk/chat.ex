defmodule TalkTalk.Chat do
  use Ash.Domain, otp_app: :talk_talk, extensions: [AshPhoenix, AshAi]

  tools do
    tool :my_conversations, TalkTalk.Chat.Conversation, :my_conversations do
      description """
      List the conversations available to the current user.
      """
    end

    tool :message_history_for_conversation, TalkTalk.Chat.Message, :for_conversation do
      description """
      Retrieve the message history for a specific conversation.
      """
    end
  end

  resources do
    resource TalkTalk.Chat.Conversation do
      define :create_conversation, action: :create
      define :get_conversation, action: :read, get_by: [:id]
      define :my_conversations
    end

    resource TalkTalk.Chat.Message do
      define :message_history,
        action: :for_conversation,
        args: [:conversation_id],
        default_options: [query: [sort: [inserted_at: :desc]]]

      define :create_message, action: :create
    end
  end
end
