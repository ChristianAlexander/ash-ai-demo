defmodule TalkTalk.Accounts do
  use Ash.Domain,
    otp_app: :talk_talk

  resources do
    resource TalkTalk.Accounts.Token
    resource TalkTalk.Accounts.User
  end
end
