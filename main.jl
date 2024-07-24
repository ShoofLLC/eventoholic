using YAML
using HTTP
using Base64
using JSON

API_TOKEN = if haskey(ENV, "API_TOKEN") ENV["API_TOKEN"] else nothing end
X_API_KEY = if haskey(ENV, "X_API_KEY") ENV["X_API_KEY"] else nothing end
API_ENDPOINT = if haskey(ENV, "API_ENDPOINT") ENV["API_ENDPOINT"] else nothing end

function extract_event(image_path,endpoint=nothing)

    image_file = open(image_path, "r")
    image_data = read(image_file)
    close(image_file)

    # Encode the image data to base64
    base64_image = base64encode(image_data)

    show_type = [
              "Dance",
              "Cabaret",
              "Stand-up Comedy"
             ]

    highlights = ["inside",
                  "outside",
                  "terrace",
                  "air conditioning",
                  "free drink",
                  "live music",
                  "show",
                  "free entrance"]

    # Create the payload 
    data_payload = Dict(
    "model" => "claude-3-5-sonnet-20240620",
    "max_tokens" => 1024,
    "messages" => [Dict(
        "role" => "user",
        "content" => [
            Dict(
                "type" => "image",
                "source" => Dict(
                    "type" => "base64",
                    "media_type" => "image/jpeg",
                    "data" => base64_image 
                )
            ),
            Dict(
                "type" => "text",
                "text" => "Create a json formatted event from this event poster. The recommended event highlights are $highlights. The only allowed types of shows are strictly $show_type which are also case-sensitive. The format of the json has to be as follows:
                {
                    \"title\": \"\",
                    \"types\": [
                        \"\"
                    ],
                    \"utcStartDateTime\": \"YYYY-MM-DD HH:mm\",
                    \"utcEndDateTime\": \"YYYY-MM-DD HH:mm\",
                    \"subtitle\": \"\",
                    \"signupLink\": \"\",
                    \"description\": \"\",
                    \"highlights\": [
                        \"\"
                    ],
                }
                Strictly fill up the fields above nothing else. The description should only summarize the show type and the location of the event. Assume end of the day on midnight if there's no end time mentioned. Return only the contents of the json file, nothing else."
            )
        ]
       )]
    )

    # Define the API endpoint
    api_url = "https://api.anthropic.com/v1/messages"

    # Define the headers
    headers = Dict( 
        "x-api-key" => X_API_KEY,
        "anthropic-version" => "2023-06-01",
        "content-type" => "application/json"
       )

    # Make an API call to a the anthropic endpoint
    response = HTTP.post(api_url, headers, json(data_payload))
    out = JSON.Parser.parse(String(response.body))
    event_details = JSON.Parser.parse(out["content"][1]["text"])
    
    # Your endpoint token (not anthropic)
    event_details["idToken"] = API_TOKEN 

    # Put the poster as a flyer
    event_details["flyers"] = ["data:image/jpeg;base64,$base64_image"]
    
    # Post to your endpoint
    if endpoint!==nothing
        HTTP.post("$endpoint", Dict(), json(event_details)) 
    else
        println("No endpoint defined, printing the json request only")
        println(json(event_details))
    end
end

function main()
    input_list = YAML.load_file("./input_list.yml")
    image_location = "./image.jpeg"
    if X_API_KEY!==nothing
        for url in input_list["urls"]
            download(url, image_location)
            try
                extract_event(image_location,API_ENDPOINT)
            finally
                rm(image_location)
            end
        end
    else
        println("No API key for anthropic api found. Please define the env variable X_API_KEY")
    end
end

main()
