defmodule MailSense.Mail.Category do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "categories" do
    field :name, :string
    field :description, :string

    belongs_to :user, MailSense.Accounts.User
    has_many :emails, MailSense.Mail.Email

    timestamps()
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :description, :user_id])
    |> validate_required([:name, :user_id])
  end
end
