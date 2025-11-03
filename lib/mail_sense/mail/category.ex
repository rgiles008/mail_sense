defmodule MailSense.Mail.Category do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "categories" do
    field :name, :string
    field :description, :string
    field :exemplar, :string
    field :rules, :map, default: %{}
    field :gmail_label_id

    belongs_to :user, MailSense.Accounts.User
    has_many :emails, MailSense.Mail.Email

    timestamps()
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :description, :user_id, :exemplar, :rules, :gmail_label_id])
    |> validate_required([:name, :user_id, :rules])
  end
end
