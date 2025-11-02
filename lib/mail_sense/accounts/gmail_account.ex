defmodule MailSense.Accounts.GmailAccount do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "gmail_accounts" do
    field :email, :string
    field :access_token, :string
    field :refresh_token, :string
    field :expires_at, :utc_datetime

    belongs_to :user, MailSense.Accounts.User

    timestamps()
  end

  def changeset(gmail_account, attrs) do
    gmail_account
    |> cast(attrs, [:email, :access_token, :refresh_token, :expires_at])
    |> validate_required([:user_id, :email, :access_token, :refresh_token])
    |> unique_constraint([:email, :user_id])
  end
end
