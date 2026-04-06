defmodule WaterWeb.GardenLive do
  use WaterWeb, :live_view

  alias Water.Garden
  alias Water.Garden.CareItemCard
  alias Water.Households
  alias Water.Weather
  alias Water.Weather.Forecast
  alias WaterWeb.Garden.State.Modal
  require Logger

  alias WaterWeb.Garden.Board.{
    CareSectionComponents,
    EmptyStateComponents,
    HudComponents,
    SectionComponents,
    ToolbarComponents
  }

  alias WaterWeb.Garden.Care.ActionComponents, as: CareActionComponents
  alias WaterWeb.Garden.Item.{DetailModalComponents, FormModalComponents}
  alias WaterWeb.Garden.Shared.ModalComponents

  alias WaterWeb.GardenLive.{CareActions, Modals, Navigation}

  @active_member_session_key "active_member_id"
  @item_form_param "item"
  @schedule_form_param "schedule_watering"

  @impl true
  def mount(_params, session, socket) do
    household = Households.get_default_household!()
    members = Households.list_members(household)

    active_member =
      Navigation.active_member_from_session!(
        members,
        Map.get(session, @active_member_session_key)
      )

    today = Navigation.household_today(household)
    sections = Garden.list_sections(household)

    section_lookup = Map.new(sections, &{&1.id, &1})

    {:ok,
     socket
     |> assign(:household, household)
     |> assign(:active_member, active_member)
     |> assign(:today, today)
     |> assign(:sections, sections)
     |> assign(:section_lookup, section_lookup)
     |> assign(:tool_mode, :browse)
     |> assign(:page_title, "Garden")
     |> assign(:board, nil)
     |> assign(:current_filter, :all)
     |> assign(:filter_query_params, %{})
     |> assign(:care_action, nil)
     |> assign(:care_feedback, nil)
     |> assign(:weather_forecast_state, :loading)
     |> assign(:temperature_forecast_url, nil)
     |> assign(:rain_forecast_url, nil)
     |> assign(:modal, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter = Navigation.parse_filter(params)
    board = Garden.list_board(socket.assigns.household, filter, socket.assigns.today)

    {:noreply,
     socket
     |> assign(:board, board)
     |> assign(:current_filter, filter)
     |> assign(:filter_query_params, Navigation.filter_query_params(filter))
     |> CareActions.clear_care_surface()
     |> Modals.apply_live_action(socket.assigns.live_action, params, filter)}
  end

  @impl true
  def handle_event("validate_item", %{@item_form_param => item_params}, socket) do
    Modals.validate_item(socket, item_params)
  end

  @impl true
  def handle_event("save_item", %{@item_form_param => item_params}, socket) do
    Modals.save_item(socket, item_params)
  end

  @impl true
  def handle_event("switch_tool_mode", %{"mode" => raw_mode}, socket) do
    {:noreply,
     socket
     |> assign(:tool_mode, Navigation.parse_tool_mode(raw_mode))
     |> CareActions.clear_care_surface()}
  end

  @impl true
  def handle_event(
        "escape_tool_mode",
        %{"key" => "Escape"},
        %{assigns: %{care_action: %_{} = _care_action}} = socket
      ) do
    {:noreply, CareActions.clear_care_action(socket)}
  end

  @impl true
  def handle_event(
        "escape_tool_mode",
        %{"key" => "Escape"},
        %{assigns: %{modal: %Modal{} = modal}} = socket
      ) do
    {:noreply, push_patch(socket, to: modal.close_path)}
  end

  @impl true
  # Reset the tool mode, switch back to browse mode
  def handle_event(
        "escape_tool_mode",
        %{"key" => "Escape"},
        %{assigns: %{tool_mode: tool_mode}} = socket
      )
      when tool_mode in [:water, :soil_check, :manual_needs_watering] do
    {:noreply,
     socket
     |> assign(:tool_mode, :browse)
     |> CareActions.clear_care_surface()}
  end

  # Noop for escape_tool_mode in browse mode
  def handle_event("escape_tool_mode", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("interact_with_item", params, socket) do
    raw_item_id = Map.get(params, "item-id")

    case Navigation.board_item_card(
           socket.assigns.board,
           Navigation.parse_item_id(raw_item_id)
         ) do
      %CareItemCard{} = item_card ->
        CareActions.handle_item_interaction(socket, item_card)

      nil ->
        {:noreply,
         socket
         |> CareActions.clear_care_surface()
         |> refresh_board()
         |> put_flash(:error, "That item is no longer available on this board.")}
    end
  end

  @impl true
  def handle_event("water_from_detail", _params, socket) do
    case Modals.detail_item_card(socket) do
      %CareItemCard{} = item_card ->
        CareActions.execute_water_action(socket, item_card)

      nil ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_schedule_from_detail", _params, socket) do
    case Modals.detail_item_card(socket) do
      %CareItemCard{} = item_card ->
        CareActions.execute_clear_schedule_action(socket, item_card)

      nil ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_detail_care_action", %{"kind" => raw_kind}, socket) do
    case {Navigation.parse_interaction_kind(raw_kind), Modals.detail_item_card(socket)} do
      {kind, %CareItemCard{} = item_card} when kind in [:soil_check, :schedule_watering] ->
        {:noreply, CareActions.open_care_action(socket, kind, item_card)}

      _other ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_care_action", _params, socket) do
    {:noreply, CareActions.clear_care_action(socket)}
  end

  @impl true
  def handle_event("show_schedule_custom_days", _params, socket) do
    {:noreply,
     CareActions.update_schedule_action(socket, fn action ->
       %{
         action
         | mode: :custom_days,
           form: CareActions.schedule_form(action.item_card, socket.assigns.today),
           error: nil
       }
     end)}
  end

  @impl true
  def handle_event("show_schedule_date", _params, socket) do
    {:noreply,
     CareActions.update_schedule_action(socket, fn action ->
       %{
         action
         | mode: :custom_date,
           form: CareActions.schedule_form(action.item_card, socket.assigns.today),
           error: nil
       }
     end)}
  end

  @impl true
  def handle_event("show_schedule_picker", _params, socket) do
    {:noreply, CareActions.update_schedule_action(socket, &%{&1 | mode: :picker, error: nil})}
  end

  @impl true
  def handle_event("change_schedule_custom_days", %{@schedule_form_param => params}, socket) do
    {:noreply,
     CareActions.update_schedule_action(socket, fn action ->
       %{
         action
         | form: CareActions.schedule_form(action.item_card, socket.assigns.today, params),
           error: nil
       }
     end)}
  end

  @impl true
  def handle_event("change_schedule_target", %{@schedule_form_param => params}, socket) do
    {:noreply,
     CareActions.update_schedule_action(socket, fn action ->
       %{
         action
         | form: CareActions.schedule_form(action.item_card, socket.assigns.today, params),
           error: nil
       }
     end)}
  end

  @impl true
  def handle_event("submit_schedule_usual", _params, socket) do
    CareActions.execute_schedule_action(socket, :usual_interval)
  end

  @impl true
  def handle_event("submit_schedule_custom_days", %{@schedule_form_param => params}, socket) do
    socket =
      CareActions.update_schedule_action(socket, fn action ->
        %{
          action
          | form: CareActions.schedule_form(action.item_card, socket.assigns.today, params),
            error: nil
        }
      end)

    case Map.get(params, "days") |> CareActions.parse_schedule_days() do
      {:ok, days} ->
        CareActions.execute_schedule_action(socket, {:days, days})

      :error ->
        {:noreply, CareActions.put_care_action_error(socket, "Enter a positive number of days.")}
    end
  end

  @impl true
  def handle_event("submit_schedule_target", %{@schedule_form_param => params}, socket) do
    socket =
      CareActions.update_schedule_action(socket, fn action ->
        %{
          action
          | form: CareActions.schedule_form(action.item_card, socket.assigns.today, params),
            error: nil
        }
      end)

    case CareActions.schedule_postpone_days(socket, Map.get(params, "target_on")) do
      {:ok, postpone_days} ->
        CareActions.execute_schedule_action(socket, postpone_days)

      {:same_due_on, %Date{}} ->
        {:noreply, CareActions.clear_care_action(socket)}

      :error ->
        {:noreply,
         CareActions.put_care_action_error(socket, "Choose a date after the current due date.")}
    end
  end

  @impl true
  def handle_event("submit_schedule_preset", %{"preset" => preset}, socket) do
    target_on =
      case preset do
        "today" -> socket.assigns.today
        "tomorrow" -> Date.add(socket.assigns.today, 1)
        _other -> nil
      end

    case target_on do
      %Date{} = date -> CareActions.execute_schedule_preset(socket, date)
      nil -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("weather_location_ready", params, socket) do
    with {:ok, latitude} <- parse_coordinate(Map.get(params, "latitude")),
         {:ok, longitude} <- parse_coordinate(Map.get(params, "longitude")) do
      socket =
        socket
        |> assign(
          :temperature_forecast_url,
          Weather.temperature_forecast_url(latitude, longitude)
        )
        |> assign(:rain_forecast_url, Weather.rain_forecast_url(latitude, longitude))

      with {:ok, forecast} <- Weather.fetch_forecast(latitude, longitude) do
        log_weather_forecast(forecast)
        {:noreply, assign(socket, :weather_forecast_state, {:ok, forecast})}
      else
        _error ->
          # If the API fetch fails we deliberately clear the external links too,
          # so the cards read as unavailable context rather than navigable data.
          {:noreply,
           socket
           |> assign(:temperature_forecast_url, nil)
           |> assign(:rain_forecast_url, nil)
           |> assign(:weather_forecast_state, {:error, :unavailable})}
      end
    else
      _error ->
        {:noreply,
         socket
         |> assign(:temperature_forecast_url, nil)
         |> assign(:rain_forecast_url, nil)
         |> assign(:weather_forecast_state, {:error, :unavailable})}
    end
  end

  @impl true
  def handle_event("weather_location_unavailable", params, socket) do
    {:noreply,
     socket
     |> assign(:temperature_forecast_url, nil)
     |> assign(:rain_forecast_url, nil)
     |> assign(:weather_forecast_state, {:error, parse_weather_reason(params)})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active_member={@active_member}>
      <section
        id="garden-shell"
        data-tool-mode={@tool_mode}
        phx-hook="GardenLucideIcons"
        phx-window-keydown="escape_tool_mode"
        class="garden-shell space-y-6 pb-28 md:pb-8"
      >
        <HudComponents.hud_section
          today={@today}
          weather_forecast_state={@weather_forecast_state}
          temperature_forecast_url={@temperature_forecast_url}
          rain_forecast_url={@rain_forecast_url}
        />

        <CareSectionComponents.care_section
          :if={@board.needs_care_items != []}
          item_cards={@board.needs_care_items}
          tool_mode={@tool_mode}
          care_feedback={@care_feedback}
          today={@today}
          counts={@board.counts}
        />

        <section
          id="garden-board-controls"
          class="garden-panel-soft rounded-[1.75rem] px-4 py-3"
        >
          <div class="flex flex-col gap-3 md:flex-row md:items-center">
            <div class="hidden shrink-0 md:block">
              <ToolbarComponents.tool_bar
                id="tool-dock-desktop"
                tool_mode={@tool_mode}
                query_params={@filter_query_params}
                can_add_item?={@sections != []}
                compact?={true}
                embedded?={true}
              />
            </div>

            <div class="min-w-0 flex-1">
              <ToolbarComponents.filter_bar
                filter={@current_filter}
                embedded?={true}
              />
            </div>
          </div>
        </section>

        <%= cond do %>
          <% Enum.empty?(@sections) -> %>
            <EmptyStateComponents.empty_state
              id="garden-board-empty"
              title="This board needs a section first"
              body="Phase 5 turns the board into a real board, but section management is still backend-only for now."
              action_text="Create or seed a section first, then add items from the board."
            />
          <% Enum.empty?(@board.sections) -> %>
            <EmptyStateComponents.empty_state
              id="garden-filter-empty"
              title="Nothing matches this filter"
              body={EmptyStateComponents.empty_filter_body(@current_filter)}
            />
          <% true -> %>
            <section
              id="garden-board"
              class="grid gap-5 xl:grid-cols-2"
            >
              <SectionComponents.garden_section
                :for={section_card <- @board.sections}
                section_card={section_card}
                tool_mode={@tool_mode}
                care_feedback={@care_feedback}
                today={@today}
              />
            </section>
        <% end %>

        <div class="fixed inset-x-0 bottom-0 z-30 px-4 pb-[calc(env(safe-area-inset-bottom)+1rem)] md:hidden">
          <ToolbarComponents.tool_bar
            id="tool-dock-mobile"
            tool_mode={@tool_mode}
            query_params={@filter_query_params}
            can_add_item?={@sections != []}
            mobile?={true}
          />
        </div>

        <CareActionComponents.care_action_modal
          :if={@care_action != nil}
          care_action={@care_action}
          today={@today}
        />

        <FormModalComponents.item_form_modal
          :if={@modal != nil and @modal.kind in [:new_form, :edit_form]}
          id="item-form-modal"
          modal={@modal}
          sections={@sections}
        />

        <ModalComponents.modal_frame
          :if={@modal != nil and @modal.kind == :new_unavailable}
          id="item-form-unavailable-modal"
          title={@modal.title}
          close_patch={@modal.close_path}
        >
          <div class="space-y-3">
            <p class="garden-text-muted text-sm leading-6">
              Add Item is disabled until the household has at least one section. Sections are still managed through the backend in this phase.
            </p>
            <div class="flex justify-end">
              <.link
                patch={@modal.close_path}
                class="garden-button-secondary inline-flex items-center rounded-full px-4 py-2 text-sm font-medium"
              >
                Back to board
              </.link>
            </div>
          </div>
        </ModalComponents.modal_frame>

        <DetailModalComponents.item_detail_modal
          :if={@modal != nil and @modal.kind == :show_detail}
          id="item-detail-modal"
          modal={@modal}
          section_lookup={@section_lookup}
          edit_patch={
            Navigation.edit_item_path(@modal.item_detail.item_card.item.id, @filter_query_params)
          }
          care_feedback={@care_feedback}
          today={@today}
        />
      </section>
    </Layouts.app>
    """
  end

  @spec refresh_board(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp refresh_board(socket) do
    board =
      Garden.list_board(
        socket.assigns.household,
        socket.assigns.current_filter,
        socket.assigns.today
      )

    assign(socket, :board, board)
  end

  @spec parse_coordinate(nil | binary() | number()) :: {:ok, float()} | :error
  defp parse_coordinate(value) when is_float(value), do: {:ok, value}
  defp parse_coordinate(value) when is_integer(value), do: {:ok, value / 1}

  defp parse_coordinate(value) when is_binary(value) do
    case Float.parse(value) do
      {coordinate, ""} -> {:ok, coordinate}
      _other -> :error
    end
  end

  defp parse_coordinate(_value), do: :error

  @spec parse_weather_reason(map()) :: :denied | :unsupported | :timeout | :unavailable
  defp parse_weather_reason(%{"reason" => "denied"}), do: :denied
  defp parse_weather_reason(%{"reason" => "unsupported"}), do: :unsupported
  defp parse_weather_reason(%{"reason" => "timeout"}), do: :timeout
  defp parse_weather_reason(_params), do: :unavailable

  # Note: Haven't tested all the codes yet, this log helps to verify the mappings.
  # Can be eventually removed.
  @spec log_weather_forecast(Forecast.t()) :: :ok
  defp log_weather_forecast(%Forecast{} = forecast) do
    today_day = Forecast.today_day(forecast)
    tomorrow_day = Forecast.tomorrow_day(forecast)
    next_rain_day = Forecast.next_rain_day(forecast)

    Logger.debug(fn ->
      "garden weather forecast " <>
        inspect(%{
          today_code: today_day && today_day.weather_code,
          tomorrow_code: tomorrow_day && tomorrow_day.weather_code,
          next_rain_code: next_rain_day && next_rain_day.weather_code,
          next_rain_date: next_rain_day && next_rain_day.date
        })
    end)

    :ok
  end
end
