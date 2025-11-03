defmodule MailSenseWeb.Router do
  use MailSenseWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MailSenseWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/auth", MailSenseWeb do
    pipe_through :browser
    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
    delete "/logout", AuthController, :delete
  end

  scope "/", MailSenseWeb do
    pipe_through [:browser, :require_user]
    live "/", DashboardLive
    live "/categories/new", CategoryFormLive
    live "/categories/:id", CategoryShowLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", MailSenseWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:mail_sense, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MailSenseWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  defp fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)

    assign(conn, :current_user, user_id && MailSense.Accounts.get_user(user_id))
  end

  defp require_user(conn, _opts) do
    if conn.assigns[:current_user],
      do: conn,
      else: Phoenix.Controller.redirect(conn, to: "/auth/google") |> Plug.Conn.halt()
  end
end
