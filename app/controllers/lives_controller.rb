class LivesController < ApplicationController
	layout "form"

	def new
		@live = Live.new
	end

	def create
		@live = Live.new(live_params)

		if @live.save
      redirect_to 'success'
    else
			flash[:notice] = "建立失敗"
      render 'new'
    end
	end

	def success

	end

	private
	def live_params
		params.require(:live).permit(:name, :title, :onair, :gmail,
																:fb_url, :phone, :stream_201602,
																:location, :ioh_url)
	end
end
