module EventsHelper
  def tags(event)
    event.tags.map do |tag_name|
      tag.span tag_name, class: "badge text-bg-info"
    end.join.html_safe
  end

  def epoch_description(epoch, time_range: false, slot: true)
    time = [l(epoch.start_time, format: :short)]
    time << l(epoch.end_time, format: :short) if time_range

    desc = [tag.time(time.join(" – "))]
    desc << tag.p("Slot #{epoch.start_slot}", class: "slot") if slot
    desc << epoch_progress_bar(epoch) unless epoch.future?

    desc.join("")
  end

  def epoch_progress_bar(epoch)
    tag.div(class: "progress mt-3", role: "progressbar", aria: { label: "Epoch Progress", valuemin: "0", valuemax: "100" }) do
      tag.div(class: "progress-bar", style: "width: #{epoch.progress}%") do
        number_to_percentage(epoch.progress, precision: 0)
      end
    end
  end

  def current_epoch_border_gradient(progress)
    colors = [
      "var(--bs-primary) #{progress}%",
      "var(--bs-border-color) #{100-progress}%"
    ].join(',')

    "border-color: unset !important; border-image: linear-gradient(180deg, #{colors}) 1"
  end

  def event_time(event)
    if event.momentary? || event.open_end?
      l(event.start_time.to_time, format: event.time_format&.to_sym || :short)
    elsif event.one_day?
      "#{l(event.start_time.to_time, format: :short)} – #{l(event.end_time.to_time, format: :time)}"
    else
      "#{l(event.start_time.to_time, format: event.time_format&.to_sym || :short)} – #{l(event.end_time.to_time, format: event.time_format&.to_sym || :short)}"
    end
  end

  def event_views
    ["month", "week", "list"]
  end

  def event_view_icon(view)
    view == "list" ? "bi-list-ul" : "bi-calendar-#{view}"
  end

  def render_event_view_switches
    default_classes = "event_view list-group-item list-group-item-action"
    active_classes = "active bg-secondary border-secondary"

    event_views.map do |view|
      classes = current_view == view ? [default_classes, active_classes].join(" ") : default_classes

      link_to events_path(event_params.merge(view: view)), class: classes, data: { view: view } do
        tag.i(nil, class: "#{event_view_icon(view)} me-1") + view.upcase_first
      end
    end.join.html_safe
  end

  def render_event_filters
    EventFilterRegistry.registered.sort.to_h.map do |category, filters|
      html_id = category.parameterize

      links = filters.map do |filter_param, filter|
        dataset = {
          "action": "change->filters#toggleFilter",
          "filter-param": filter_param,
          "filter-default": filter[:default]
        }
        checked = event_param_filters.is_on?(filter_param)
        checkbox_name = "filter_#{filter_param}"

        tag.div class: "event_filter form-switch list-group-item" do
          check_box_tag(checkbox_name, nil, checked, data: dataset, class: "form-check-input me-2 float-none", role: "switch") +
            tag.label(filter[:label], class: "form-check-label small", for: checkbox_name)
        end
      end.join.html_safe

      tag.div class: "accordion-item" do
        filter_accordion_heading(category, html_id) + filter_accordion_body(links, html_id)
      end
    end.join.html_safe
  end

  def filter_list(links)
    tag.ul class: "list-group list-group-flush mb-4" do
      links
    end
  end

  def filter_accordion_heading(title, html_id)
    tag.h2 class: "accordion-header", id: "heading_#{html_id}" do
      tag.button class: "accordion-button collapsed", type: "button", data: { "bs-toggle" => "collapse", "bs-target" => "##{html_id}" }, "aria-expanded" => "false", "aria-controls" => html_id do
        title
      end
    end
  end

  def filter_accordion_body(links, html_id)
    tag.div id: html_id, class: "accordion-collapse collapse", "aria-labelledby" => "heading_#{html_id}", "data-bs-parent" => "#event_filter" do
      tag.div class: "accordion-body p-0" do
        filter_list(links)
      end
    end
  end

  def current_view
    event_params.fetch(:view, "month")
  end

  def filter_params
    event_params.fetch(:filter, {}).merge(
      stake_address: event_params[:stake_address])
  end

  def current_start_date
    event_params.fetch(:start_date, Date.current).to_date
  end

  def date_range
    current_view == "week" ? week_date_range : month_date_range
  end

  def week_date_range
    (current_start_date.beginning_of_week..current_start_date.end_of_week).to_a
  end

  def month_date_range
    (current_start_date.beginning_of_month..current_start_date.end_of_month).to_a
  end

  # direction can either be :+ or :- for prev/next
  def start_date(direction=nil)
    return Time.current.to_date unless direction

    if current_view == "week"
      date_range.first.public_send(direction, 1.week)
    else
      date_range.first.public_send(direction, 1.month)
    end
  end

  def url_for_previous_view
    url_for(event_params.merge(
      start_date: start_date(:-).iso8601
    ).merge(view: current_view))
  end

   def url_for_next_view
    url_for(event_params.merge(
      start_date: start_date(:+).iso8601
    ).merge(view: current_view))
  end

  def url_for_today_view
    url_for(
      event_params.merge(
        start_date: start_date,
        view: current_view,
        anchor: start_date
      )
    )
  end
end
