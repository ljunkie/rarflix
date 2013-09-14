'*
'* Functions related to getting ratings and critiques from Rotten Tomatoes API
'*

Function getRottenTomatoesData(movieTitle)
    movieTitle = HttpEncode(movieTitle)
    url = "http://api.rottentomatoes.com/api/public/v1.0/movies.json?apikey=tk9u9ybr6mnjx9jfvxbumqjy&page_limit=1&q=" + movieTitle
    Debug("Calling Rotten Tomatoes API for " + movieTitle)

    httpRequest = NewHttp(url)
    data = httpRequest.GetToStringWithTimeout(60)

    ' Note: in the future consider asking for 2-3 results from the API and running the titles through an algorithm
    ' to determine which movie result matches the best.
    data = data.Trim() 
    json = ParseJSON(data)
    if type(json) = "roAssociativeArray" then
        movie = json.movies[0]
        if movie <> invalid AND movie.ratings <> invalid AND movie.ratings.critics_score <> invalid then
            ' ParseJSON does not handle negative numbers, so this ugly check needs to be performed on the JSON string.
            ' Find the critics_score in the JSON string
            score_pos = INSTR(0, data, Chr(34) + "critics_score" + Chr(34) +":")
            if score_pos <> invalid then
                ' If it is found, check the 2 characters after to see if they match the string "-1"
                rating = MID(data, score_pos + 16, 2)
                if rating = "-1" then
                    movie.ratings.critics_score = -1
                endif
            endif
            return movie
        endif
    endif
End Function
