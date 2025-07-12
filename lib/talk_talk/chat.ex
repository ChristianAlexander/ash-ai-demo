defmodule TalkTalk.Chat do
  use Ash.Domain, otp_app: :talk_talk, extensions: [AshPhoenix]

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
