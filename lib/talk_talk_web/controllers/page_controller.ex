defmodule TalkTalkWeb.PageController do
  use TalkTalkWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
