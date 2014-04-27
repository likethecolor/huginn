require 'alchemy_api'

module Agents
  class AlchemySentimentAnalysisAgent < Agent
    include AlchemyConcern

    OptionKeyContent                     = 'content'
    OptionKeyExpectedReceivePeriodInDays = 'expected_receive_period_in_days'
    OptionKeyAlchemyApiKey               = 'alchemy_api_key'
    OptionKeyDiscardUnknownEvents        = 'discard_unknown_events'

    ResponseKeyType  = 'type'
    ResponseKeyScore = 'score'
    ResponseKeyMixed = 'mixed'

    DefaultOptionContent                     = '$.text'
    DefaultOptionExpectedReceivePeriodInDays = 1
    DefaultOptionAlchemyApiKey               = 'abc123'
    DefaultOptionDiscardUnknownEvents        = 'false'

    UnknownEventType  = 'unknown'
    UnknownEventScore = -1.0
    UnknownEventMixed = false

    cannot_be_scheduled!

    description <<-MD
      The AlchemySentimentAnalysisAgent requests sentiment analysis of specified
      text by sending that text to the [AlchemyAPI service](http://www.alchemyapi.com/).

      Make sure the text this agent analyzes has sufficient context to get
      reasonable results (i.e., generally, more text will provide greater context).

      Provide a JSONPath in the `#{OptionKeyContent}` field pointing to where the text to be
      analyzed can be found.

      The maximum allowable time in days between events received by this agent
      should be set using `#{OptionKeyExpectedReceivePeriodInDays}`.

      AlchemyAPI credentials must be supplied as either [credentials](/user_credentials)
      called `#{OptionKeyAlchemyApiKey}` or as options to this Agent also called
      `#{OptionKeyAlchemyApiKey}`.

      You'll need to request an API Key [here http://www.alchemyapi.com/api/register.html](http://www.alchemyapi.com/api/register.html)

      When a response returns from Alchemy API that the system cannot parse an
      "unknown" event is logged.  Set `#{OptionKeyDiscardUnknownEvents}` to true to
      discard these events.  Otherwise, these events will be recorded.
    MD

    event_description <<-MD
      Events look like:
          {
            "#{DefaultOptionContent}": "The quick brown fox jumps over the lazy dog.",
            "#{ResponseKeyType}": "positive",
            "#{ResponseKeyScore}": "0.234811",
            "#{ResponseKeyMixed}": "1"
          }
          {
            "#{DefaultOptionContent}": "The quick brown fox jumps over the lazy dog.",
            "#{ResponseKeyType}": "neutral"
          }
    MD

    def default_options
      {
          OptionKeyContent                     => DefaultOptionContent,
          OptionKeyExpectedReceivePeriodInDays => DefaultOptionExpectedReceivePeriodInDays,
          OptionKeyAlchemyApiKey               => DefaultOptionAlchemyApiKey,
          OptionKeyDiscardUnknownEvents        => DefaultOptionDiscardUnknownEvents
      }
    end

    def working?
      last_receive_at && last_receive_at > options[OptionKeyExpectedReceivePeriodInDays].to_i.days.ago && !recent_error_logs?
    end

    def post_request(content)
      configure_alchemy
      response = AlchemyAPI.search(:sentiment_analysis, :text => content)
      if response.nil?
        response = create_empty_response
      end
      response
    end

    def parse_response(response)
      response[ResponseKeyType]  ||= UnknownEventType
      response[ResponseKeyScore] ||= UnknownEventScore
      response[ResponseKeyMixed] ||= UnknownEventMixed
      response
    end

    def create_empty_response
      response                   = Hash.new
      response[ResponseKeyType]  = UnknownEventType
      response[ResponseKeyScore] = UnknownEventScore
      response[ResponseKeyMixed] = UnknownEventMixed
      response
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        Utils.values_at(event.payload, options['content']).each do |content|
          response = post_request(content)
          response = parse_response(response)

          if (create_event?(response[ResponseKeyType], options[OptionKeyDiscardUnknownEvents]))
            Rails.logger.info "logger: alchemy response unknown for content #{content}:#{response}"
            next
          end

          create_event :payload => {OptionKeyContent => content,
                                    ResponseKeyType  => response[ResponseKeyType],
                                    ResponseKeyScore => response[ResponseKeyScore],
                                    ResponseKeyMixed => response[ResponseKeyMixed]}
        end
      end
    end

    def create_event?(type, discard_unknown_events)
      return (type == UnknownEventType) && discard_unknown_events == 'true'
    end

    def validate_options
      errors.add(:base, "#{OptionKeyContent} and #{OptionKeyExpectedReceivePeriodInDays} must be present") unless options[OptionKeyContent].present? && options[OptionKeyExpectedReceivePeriodInDays].present?
    end
  end
end
