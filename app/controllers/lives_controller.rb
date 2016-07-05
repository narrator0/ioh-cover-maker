class LivesController < ApplicationController
	layout "form"

	def new
		@live = Live.new
	end

	def create
		@live = Live.new(live_params)

		talk = Talk.where("title like ? ", "%#{@live.name}%").first

		@live.live_school_id = talk.live_school_id
		@live.live_department_id = talk.live_department_id
		@live.ioh_url = "https://ioh.tw/talks/#{talk.post_name}"

		if talk && @live.save
      redirect_to lives_success_path
    else
			flash[:alert] = @live.errors
      render :new
    end
	end

	def success
	end

	def agenda
	end

	private
	def live_params
		params.require(:live).permit(:name, :gmail, :fb_url, 
																 :phone, :stream_201602, :location, { live_time_ids: [] })
	end
end
