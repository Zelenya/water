defmodule WaterWeb.Garden.Item.FormModalComponents do
  use WaterWeb, :html

  alias Water.Garden.{CareItem, Section}
  alias WaterWeb.Garden.Shared.ModalComponents
  alias WaterWeb.Garden.State.Modal

  attr :id, :string, required: true
  attr :modal, :any, required: true
  attr :sections, :list, required: true

  def item_form_modal(assigns) do
    ~H"""
    <ModalComponents.modal_frame id={@id} title={@modal.title} close_patch={@modal.close_path}>
      <div class="space-y-5">
        <.form
          for={@modal.form}
          id="garden-item-form"
          phx-change="validate_item"
          phx-submit="save_item"
        >
          <div class="grid gap-4 sm:grid-cols-2">
            <div class="sm:col-span-2">
              <.input field={@modal.form[:name]} type="text" label="Item name" />
            </div>

            <.input
              field={@modal.form[:type]}
              type="select"
              label="Item type"
              options={item_type_options()}
              prompt="Choose a type"
            />

            <.input
              field={@modal.form[:section_id]}
              type="select"
              label="Section"
              options={section_options(@sections)}
              prompt="Choose a section"
            />

            <div class="sm:col-span-2 space-y-3">
              <fieldset id="garden-item-schedule-mode">
                <legend class="garden-text-primary text-sm font-semibold">Schedule</legend>
                <div class="mt-2 grid gap-2 sm:grid-cols-2">
                  <label class={schedule_mode_option_classes(@modal.schedule_mode, :recurring)}>
                    <input
                      type="radio"
                      name={schedule_mode_input_name(@modal.form)}
                      value="recurring"
                      checked={@modal.schedule_mode == :recurring}
                      class="sr-only"
                    />
                    <span class="block text-sm font-semibold">Recurring</span>
                    <span class="garden-text-muted block text-xs">Water on a repeating rhythm</span>
                  </label>

                  <label class={schedule_mode_option_classes(@modal.schedule_mode, :no_schedule)}>
                    <input
                      type="radio"
                      name={schedule_mode_input_name(@modal.form)}
                      value="no_schedule"
                      checked={@modal.schedule_mode == :no_schedule}
                      class="sr-only"
                    />
                    <span class="block text-sm font-semibold">No schedule</span>
                    <span class="garden-text-muted block text-xs">
                      Keep it off the recurring schedule
                    </span>
                  </label>
                </div>
              </fieldset>
            </div>

            <div :if={@modal.schedule_mode == :recurring} class="sm:col-span-2">
              <.input
                field={@modal.form[:watering_interval_days]}
                type="number"
                label="Water every (days)"
                min="1"
              />
            </div>
          </div>

          <div class="mt-6 flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
            <.link
              id="garden-item-cancel"
              patch={@modal.close_path}
              class="garden-button-secondary inline-flex items-center justify-center rounded-full px-4 py-2.5 text-sm font-medium"
            >
              Cancel
            </.link>

            <button
              id="garden-item-submit"
              type="submit"
              class="garden-button-primary inline-flex items-center justify-center rounded-full px-5 py-2.5 text-sm font-semibold"
            >
              {item_form_submit_label(@modal.kind)}
            </button>
          </div>
        </.form>
      </div>
    </ModalComponents.modal_frame>
    """
  end

  @spec item_type_options() :: [{String.t(), CareItem.kind()}]
  defp item_type_options do
    [{"Plant", :plant}, {"Area", :area}, {"Bed", :bed}]
  end

  @spec section_options([Section.t()]) :: [{String.t(), Section.id()}]
  defp section_options(sections) do
    Enum.map(sections, &{&1.name, &1.id})
  end

  @spec item_form_submit_label(Modal.kind()) :: String.t()
  defp item_form_submit_label(:edit_form), do: "Save changes"
  defp item_form_submit_label(:new_form), do: "Add item"

  @spec schedule_mode_input_name(Phoenix.HTML.Form.t()) :: String.t()
  defp schedule_mode_input_name(form), do: "#{form.name}[schedule_mode]"

  @spec schedule_mode_option_classes(:recurring | :no_schedule | nil, :recurring | :no_schedule) ::
          [String.t()]
  defp schedule_mode_option_classes(selected_mode, option_mode) do
    [
      "rounded-[1.2rem] border px-4 py-3 transition cursor-pointer",
      selected_mode == option_mode && "border-[var(--garden-water-highlight-border)] bg-white/80",
      selected_mode != option_mode && "border-white/30 bg-white/30"
    ]
  end
end
