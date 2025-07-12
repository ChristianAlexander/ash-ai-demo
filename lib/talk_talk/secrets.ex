defmodule TalkTalk.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        TalkTalk.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:talk_talk, :token_signing_secret)
  end
end
