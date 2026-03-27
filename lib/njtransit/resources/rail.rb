# frozen_string_literal: true

module NJTransit
  module Resources
    class Rail < Base
      def stations
        post_form("/api/TrainData/getStationList")
      end

      def station_messages(station: nil, line: nil)
        post_form("/api/TrainData/getStationMSG",
                  station: station || "", line: line || "")
      end

      def station_schedule(station:, njtonly: "1")
        post_form("/api/TrainData/getStationSchedule",
                  station: station, NJT_Only: njtonly)
      end

      def train_schedule(station:, njtonly: "1")
        post_form("/api/TrainData/getTrainSchedule",
                  station: station, NJT_Only: njtonly)
      end

      def train_schedule_19(station:, njtonly: "1")
        post_form("/api/TrainData/getTrainSchedule19Rec",
                  station: station, NJT_Only: njtonly)
      end

      def train_stop_list(train_id:)
        post_form("/api/TrainData/getTrainStopList",
                  trainID: train_id)
      end

      def vehicle_data
        post_form("/api/TrainData/getVehicleData")
      end

      private

      def post_form(path, params = {})
        params[:token] = client.token
        client.post_form(path, params)
      end
    end
  end
end
