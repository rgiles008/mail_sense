defmodule MailSense.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field :name, :string
    field :email, :string

    has_many :gmail_accounts, MailSense.Accounts.GmailAccount
    has_many :categories, MailSense.Mail.Category

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name])
    |> validate_required(:email)
  end
end
