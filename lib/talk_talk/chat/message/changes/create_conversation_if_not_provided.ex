defmodule TalkTalk.Chat.Message.Changes.CreateConversationIfNotProvided do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    if changeset.arguments[:conversation_id] do
      Ash.Changeset.force_change_attribute(
        changeset,
        :conversation_id,
        changeset.arguments.conversation_id
      )
    else
      Ash.Changeset.before_action(changeset, fn changeset ->
        conversation = TalkTalk.Chat.create_conversation!(Ash.Context.to_opts(context))

        Ash.Changeset.force_change_attribute(changeset, :conversation_id, conversation.id)
      end)
    end
  end
end
