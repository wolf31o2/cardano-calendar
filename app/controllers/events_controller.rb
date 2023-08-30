class EventsController < ApplicationController
  helper_method :permitted_params, :wallet_connected?, :event_param_filters

  def index
    respond_to do |f|
      f.html do
        events = Events::SimpleEvent.all(except: filters.off_filters, between: date_range)
        events += Events::Meetup.where("extras->'group_urlname' ?| array[:names]", names: filters.on_filters).between(date_range)
        if wallet_connected?
          wallet_on_filters = EventFilter.by_class("Events::Wallet").map(&:keys).flatten - filters.off_filters
          events += Events::Wallet.where(category: wallet_on_filters).with_stake_address(permitted_params[:stake_address]).between(date_range)
        end

        @epochs = Epoch.all(between: date_range, with_events: events.sort_by(&:start_time))
      end

      f.ics do
        events = Events::SimpleEvent.all(except: filters.off_filters, between: ics_date_range)
        events += Events::LeaderlogCheck.all(between: date_range) if filters.on_filters.include?("leaderlog-check")
        events += Events::Meetup.where("extras->'group_urlname' ?| array[:names]", names: filters.on_filters).between(ics_date_range)
        @epochs = Epoch.all(between: ics_date_range, with_events: events)

        render plain: ics_calendar.to_ical
      end
    end
  end

  def wallet_connected?
    @wallet_connected ||= permitted_params[:stake_address] && Wallet.where(stake_address: permitted_params[:stake_address]).exists?
  end

  def start_date
    permitted_params.fetch(:start_date, Date.today).to_time
  end

  def ics_date_range
    Time.at(Epoch::SHELLY_UNIX).utc..(Time.current.utc + 1.year)
  end

  def ics_calendar
    current_timestamp = Time.current.utc.to_i

    Icalendar::Calendar.new.tap do |cal|
      cal.ip_name = "cardano-calendar.com"
      ca.description = "My Customized Cardano Events"
      cal.refresh_interval = "P4H"

      @epochs.each do |epoch|
        cal.event do |ce|
          ce.summary = epoch.name
          ce.description = "Slots #{epoch.start_slot} – #{epoch.end_slot}"
          ce.categories = "Epoch"
          ce.dtstart = epoch.start_time.utc
          ce.dtend = epoch.end_time.utc
          ce.uid = epoch.id
          ce.sequence = current_timestamp

          epoch.events.each do |event|
            cal.event do |ce|
              ce.summary = event.name
              ce.description = event.description
              ce.dtstart = event.start_time.utc
              ce.categories = event.category
              ce.dtend = event.end_time.utc
              ce.uid = event.id
              ce.sequence = current_timestamp
            end
          end
        end
      end

      cal.publish
    end
  end

  def date_range
    if permitted_params[:view] == "list"
      start_date.beginning_of_month..start_date.end_of_month
    else
      start_date.beginning_of_month.beginning_of_week..start_date.end_of_month.end_of_week.end_of_day
    end
  end

  def filters
    @filters ||= EventParamFilters.new(permitted_params.fetch(:filter, {}))
  end
  alias_method :event_param_filters, :filters

  def permitted_params
    @params ||= params.permit(
      :format, :view, :start_date, :tz, :stake_address, filter: {}
    ).to_h.with_indifferent_access.symbolize_keys
  end
end
