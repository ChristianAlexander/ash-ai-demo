defmodule TalkTalk.Chat.Message.Changes.Respond do
  use Ash.Resource.Change
  require Ash.Query

  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatOpenAI

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      message = changeset.data

      messages =
        TalkTalk.Chat.Message
        |> Ash.Query.filter(conversation_id == ^message.conversation_id)
        |> Ash.Query.filter(id != ^message.id)
        |> Ash.Query.select([:text, :source, :tool_calls, :tool_results])
        |> Ash.Query.sort(inserted_at: :asc)
        |> Ash.read!()
        |> Enum.concat([%{source: :user, text: message.text}])

      system_prompt =
        LangChain.Message.new_system!("""
        You are a helpful chat bot.
        Your job is to use the tools at your disposal to assist the user.
        """)

      message_chain = message_chain(messages)

      new_message_id = Ash.UUID.generate()

      %{
        llm:
          ChatOpenAI.new!(%{
            model: "gpt-4o",
            stream: true,
            custom_context: Map.new(Ash.Context.to_opts(context))
          })
      }
      |> LLMChain.new!()
      |> LLMChain.add_message(system_prompt)
      |> LLMChain.add_messages(message_chain)
      # add the names of tools you want available in your conversation here.
      # i.e tools: [:lookup_weather]
      |> AshAi.setup_ash_ai(
        otp_app: :talk_talk,
        tools: [:my_conversations, :message_history_for_conversation],
        actor: context.actor
      )
      |> LLMChain.add_callback(%{
        on_llm_new_delta: fn _model, data ->
          if data.content && data.content != "" do
            TalkTalk.Chat.Message
            |> Ash.Changeset.for_create(
              :upsert_response,
              %{
                id: new_message_id,
                response_to_id: message.id,
                conversation_id: message.conversation_id,
                text: data.content
              },
              actor: %AshAi{}
            )
            |> Ash.create!()
          end
        end,
        on_message_processed: fn _chain, data ->
          if (data.tool_calls && Enum.any?(data.tool_calls)) ||
               (data.tool_results && Enum.any?(data.tool_results)) ||
               data.content not in [nil, ""] do
            TalkTalk.Chat.Message
            |> Ash.Changeset.for_create(
              :upsert_response,
              %{
                id: new_message_id,
                response_to_id: message.id,
                conversation_id: message.conversation_id,
                complete: true,
                tool_calls:
                  data.tool_calls &&
                    Enum.map(
                      data.tool_calls,
                      &Map.take(&1, [:status, :type, :call_id, :name, :arguments, :index])
                    ),
                tool_results:
                  data.tool_results &&
                    Enum.map(
                      data.tool_results,
                      &Map.take(&1, [
                        :type,
                        :tool_call_id,
                        :name,
                        :content,
                        :display_text,
                        :is_error,
                        :options
                      ])
                    ),
                text: data.content || ""
              },
              actor: %AshAi{}
            )
            |> Ash.create!()
          end
        end
      })
      |> LLMChain.run(mode: :while_needs_response)

      changeset
    end)
  end

  defp message_chain(messages) do
    Enum.flat_map(messages, fn
      %{source: :agent} = message ->
        langchain_message =
          LangChain.Message.new_assistant!(%{
            content: message.text,
            tool_calls:
              message.tool_calls &&
                Enum.map(
                  message.tool_calls,
                  &LangChain.Message.ToolCall.new!(
                    Map.take(&1, ["status", "type", "call_id", "name", "arguments", "index"])
                  )
                )
          })

        if message.tool_results && !Enum.empty?(message.tool_results) do
          [
            langchain_message,
            LangChain.Message.new_tool_result!(%{
              tool_results:
                Enum.map(
                  message.tool_results,
                  &LangChain.Message.ToolResult.new!(
                    Map.take(&1, [
                      "type",
                      "tool_call_id",
                      "name",
                      "content",
                      "display_text",
                      "is_error",
                      "options"
                    ])
                  )
                )
            })
          ]
        else
          [langchain_message]
        end

      %{source: :user, text: text} ->
        [LangChain.Message.new_user!(text)]
    end)
  end
end
