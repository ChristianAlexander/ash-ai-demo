defmodule TalkTalkWeb.ChatLive do
  use Elixir.TalkTalkWeb, :live_view
  on_mount {TalkTalkWeb.LiveUserAuth, :live_user_required}

  def render(assigns) do
    ~H"""
    <div class="drawer md:drawer-open bg-base-200 min-h-dvh max-h-dvh">
      <input id="ash-ai-drawer" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content flex flex-col">
        <div class="navbar bg-base-300 w-full">
          <div class="flex-none md:hidden">
            <label for="ash-ai-drawer" aria-label="open sidebar" class="btn btn-square btn-ghost">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                class="inline-block h-6 w-6 stroke-current"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M4 6h16M4 12h16M4 18h16"
                >
                </path>
              </svg>
            </label>
          </div>
          <img
            src="https://github.com/ash-project/ash_ai/blob/main/logos/ash_ai.png?raw=true"
            alt="Logo"
            class="h-12"
            height="48"
          />
          <div class="mx-2 flex-1 px-2">
            <p :if={@conversation}>{build_conversation_title_string(@conversation.title)}</p>
            <p class="text-xs">AshAi</p>
          </div>
        </div>
        <div class="flex-1 flex flex-col overflow-y-scroll bg-base-200 max-h-[calc(100dvh-8rem)]">
          <div
            id="message-container"
            phx-update="stream"
            class="flex-1 overflow-y-auto px-4 py-2 flex flex-col-reverse"
          >
            <%= for {id, message} <- @streams.messages do %>
              <div
                id={id}
                class={[
                  "chat",
                  message.source == :user && "chat-end",
                  message.source == :agent && "chat-start"
                ]}
              >
                <div :if={message.source == :agent} class="chat-image avatar">
                  <div class="w-10 rounded-full bg-base-300 p-1">
                    <img
                      src="https://github.com/ash-project/ash_ai/blob/main/logos/ash_ai.png?raw=true"
                      alt="Logo"
                    />
                  </div>
                </div>
                <div :if={message.source == :user} class="chat-image avatar avatar-placeholder">
                  <div class="w-10 rounded-full bg-base-300">
                    <.icon name="hero-user-solid" class="block" />
                  </div>
                </div>
                <div class="chat-bubble">
                  {to_markdown(message.text)}
                </div>
              </div>
            <% end %>
          </div>
        </div>
        <div class="p-4 border-t h-16">
          <.form
            :let={form}
            for={@message_form}
            phx-change="validate_message"
            phx-debounce="blur"
            phx-submit="send_message"
            class="flex items-center gap-4"
          >
            <div class="flex-1">
              <input
                name={form[:text].name}
                value={form[:text].value}
                type="text"
                phx-mounted={JS.focus()}
                placeholder="Type your message..."
                class="input input-primary w-full mb-0"
                autocomplete="off"
              />
            </div>
            <button type="submit" class="btn btn-primary rounded-full">
              <.icon name="hero-paper-airplane" /> Send
            </button>
          </.form>
        </div>
      </div>

      <div class="drawer-side border-r bg-base-300 min-w-72">
        <div class="py-4 px-6">
          <.header class="text-lg mb-4">
            Conversations
          </.header>
          <div class="mb-4">
            <.link navigate={~p"/chat"} class="btn btn-primary btn-lg mb-2">
              <div class="rounded-full bg-primary-content text-primary w-6 h-6 flex items-center justify-center">
                <.icon name="hero-plus" />
              </div>
              <span>New Chat</span>
            </.link>
          </div>
          <ul class="flex flex-col-reverse" phx-update="stream" id="conversations-list">
            <%= for {id, conversation} <- @streams.conversations do %>
              <li id={id}>
                <.link
                  href={~p"/chat/#{conversation.id}"}
                  phx-click="select_conversation"
                  phx-value-id={conversation.id}
                  class={"block py-2 px-3 transition border-l-4 pl-2 mb-2 #{if @conversation && @conversation.id == conversation.id, do: "border-primary font-medium", else: "border-transparent"}"}
                >
                  {build_conversation_title_string(conversation.title)}
                </.link>
              </li>
            <% end %>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  def build_conversation_title_string(title) do
    cond do
      title == nil -> "Untitled conversation"
      is_binary(title) && String.length(title) > 25 -> String.slice(title, 0, 25) <> "..."
      is_binary(title) && String.length(title) <= 25 -> title
    end
  end

  def mount(_params, _session, socket) do
    socket = assign_new(socket, :current_user, fn -> nil end)

    TalkTalkWeb.Endpoint.subscribe("chat:conversations:#{socket.assigns.current_user.id}")

    socket =
      socket
      |> assign(:page_title, "Chat")
      |> stream(
        :conversations,
        TalkTalk.Chat.my_conversations!(actor: socket.assigns.current_user)
      )
      |> assign(:messages, [])

    {:ok, socket}
  end

  def handle_params(%{"conversation_id" => conversation_id}, _, socket) do
    conversation =
      TalkTalk.Chat.get_conversation!(conversation_id, actor: socket.assigns.current_user)

    cond do
      socket.assigns[:conversation] && socket.assigns[:conversation].id == conversation.id ->
        :ok

      socket.assigns[:conversation] ->
        TalkTalkWeb.Endpoint.unsubscribe("chat:messages:#{socket.assigns.conversation.id}")
        TalkTalkWeb.Endpoint.subscribe("chat:messages:#{conversation.id}")

      true ->
        TalkTalkWeb.Endpoint.subscribe("chat:messages:#{conversation.id}")
    end

    socket
    |> assign(:conversation, conversation)
    |> stream(:messages, TalkTalk.Chat.message_history!(conversation.id, stream?: true))
    |> assign_message_form()
    |> then(&{:noreply, &1})
  end

  def handle_params(_, _, socket) do
    if socket.assigns[:conversation] do
      TalkTalkWeb.Endpoint.unsubscribe("chat:messages:#{socket.assigns.conversation.id}")
    end

    socket
    |> assign(:conversation, nil)
    |> stream(:messages, [])
    |> assign_message_form()
    |> then(&{:noreply, &1})
  end

  def handle_event("validate_message", %{"form" => params}, socket) do
    {:noreply,
     assign(socket, :message_form, AshPhoenix.Form.validate(socket.assigns.message_form, params))}
  end

  def handle_event("send_message", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.message_form, params: params) do
      {:ok, message} ->
        if socket.assigns.conversation do
          socket
          |> assign_message_form()
          |> stream_insert(:messages, message, at: 0)
          |> then(&{:noreply, &1})
        else
          {:noreply,
           socket
           |> push_navigate(to: ~p"/chat/#{message.conversation_id}")}
        end

      {:error, form} ->
        {:noreply, assign(socket, :message_form, form)}
    end
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "chat:messages:" <> conversation_id,
          payload: message
        },
        socket
      ) do
    if socket.assigns.conversation && socket.assigns.conversation.id == conversation_id do
      {:noreply, stream_insert(socket, :messages, message, at: 0)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "chat:conversations:" <> _,
          payload: conversation
        },
        socket
      ) do
    socket =
      if socket.assigns.conversation && socket.assigns.conversation.id == conversation.id do
        assign(socket, :conversation, conversation)
      else
        socket
      end

    {:noreply, stream_insert(socket, :conversations, conversation)}
  end

  defp assign_message_form(socket) do
    form =
      if socket.assigns.conversation do
        TalkTalk.Chat.form_to_create_message(
          actor: socket.assigns.current_user,
          private_arguments: %{conversation_id: socket.assigns.conversation.id}
        )
        |> to_form()
      else
        TalkTalk.Chat.form_to_create_message(actor: socket.assigns.current_user)
        |> to_form()
      end

    assign(
      socket,
      :message_form,
      form
    )
  end

  defp to_markdown(text) do
    # Note that you must pass the "unsafe: true" option to first generate the raw HTML
    # in order to sanitize it. https://hexdocs.pm/mdex/MDEx.html#module-sanitize
    MDEx.to_html(text,
      extension: [
        strikethrough: true,
        tagfilter: true,
        table: true,
        autolink: true,
        tasklist: true,
        footnotes: true,
        shortcodes: true
      ],
      parse: [
        smart: true,
        relaxed_tasklist_matching: true,
        relaxed_autolinks: true
      ],
      render: [
        github_pre_lang: true,
        unsafe: true
      ],
      sanitize: MDEx.default_sanitize_options()
    )
    |> case do
      {:ok, html} ->
        html
        |> Phoenix.HTML.raw()

      {:error, _} ->
        text
    end
  end
end
