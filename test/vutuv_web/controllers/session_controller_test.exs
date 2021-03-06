defmodule VutuvWeb.SessionControllerTest do
  use VutuvWeb.ConnCase

  @create_attrs %{"email" => "robin@example.com", "password" => "reallyHard2gue$$"}
  @invalid_attrs %{"email" => "robin@example.com", "password" => "cannotGue$$it"}
  @unconfirmed_attrs %{"email" => "lancelot@example.com", "password" => "reallyHard2gue$$"}

  setup %{conn: conn} do
    conn = conn |> bypass_through(VutuvWeb.Router, [:browser]) |> get("/")
    add_user("lancelot@example.com")
    user = add_user_confirmed("robin@example.com")
    {:ok, %{conn: conn, user: user}}
  end

  describe "login form" do
    test "rendering login form fails for user that is already logged in", %{
      conn: conn,
      user: user
    } do
      conn = conn |> add_session(user) |> send_resp(:ok, "/")
      conn = get(conn, Routes.user_path(conn, :new))
      assert redirected_to(conn) == Routes.user_path(conn, :show, user)
    end
  end

  describe "create session" do
    test "login succeeds", %{conn: conn, user: user} do
      conn = post(conn, Routes.session_path(conn, :create), session: @create_attrs)
      assert redirected_to(conn) == Routes.user_path(conn, :show, user)
    end

    test "login fails for user that is not yet confirmed", %{conn: conn} do
      conn = post(conn, Routes.session_path(conn, :create), session: @unconfirmed_attrs)
      assert redirected_to(conn) == Routes.session_path(conn, :new)
    end

    test "login fails for user that is already logged in", %{conn: conn, user: user} do
      conn = conn |> add_session(user)
      conn = post(conn, Routes.session_path(conn, :create), session: @create_attrs)
      assert redirected_to(conn) == Routes.user_path(conn, :show, user)
    end

    test "login fails for invalid password", %{conn: conn} do
      conn = post(conn, Routes.session_path(conn, :create), session: @invalid_attrs)
      assert redirected_to(conn) == Routes.session_path(conn, :new)
    end

    test "redirects to previously requested resource", %{conn: conn, user: user} do
      conn = get(conn, Routes.user_path(conn, :edit, user))
      assert redirected_to(conn) == Routes.session_path(conn, :new)
      conn = post(conn, Routes.session_path(conn, :create), session: @create_attrs)
      assert redirected_to(conn) == Routes.user_path(conn, :edit, user)
    end
  end

  describe "rate limiting for create session" do
    @tag :rate_limiting
    test "login is blocked after user_name limit (5 every 60 seconds) is reached", %{conn: conn} do
      for _ <- 1..5 do
        conn = post(conn, Routes.session_path(conn, :create), session: @invalid_attrs)
        assert redirected_to(conn) == Routes.session_path(conn, :new)
      end

      conn = post(conn, Routes.session_path(conn, :create), session: @invalid_attrs)
      assert redirected_to(conn) == Routes.user_path(conn, :new)
      assert get_flash(conn, :error) == "Too many requests. Please try again later."
    end

    @tag :rate_limiting
    test "count is reset after successful login", %{conn: conn, user: user} do
      for _ <- 1..4 do
        conn = post(conn, Routes.session_path(conn, :create), session: @invalid_attrs)
        assert redirected_to(conn) == Routes.session_path(conn, :new)
      end

      conn = post(conn, Routes.session_path(conn, :create), session: @create_attrs)
      assert redirected_to(conn) == Routes.user_path(conn, :show, user)
      assert {:allow, 1} = Hammer.check_rate("robin@example.com:/sessions", 60_000, 5)
    end
  end

  describe "delete session" do
    test "logout succeeds and session is deleted", %{conn: conn, user: user} do
      conn = conn |> add_session(user) |> send_resp(:ok, "/")
      session_id = get_session(conn, :phauxth_session_id)
      conn = delete(conn, Routes.session_path(conn, :delete, session_id))
      assert redirected_to(conn) == Routes.user_path(conn, :new)
      conn = get(conn, Routes.user_path(conn, :edit, user))
      assert redirected_to(conn) == Routes.session_path(conn, :new)
    end
  end
end
