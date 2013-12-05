'*
'* Functions related to getting ratings and critiques from Rotten Tomatoes API
'*

Function getRottenTomatoesData(movieTitle)
    movieTitle = HttpEncode(movieTitle)
    apikey = "whvxdmyudad56xpnzp7ftrk5"
    ' ljunkie - we are now offloading some API calls to the rottentomatoes API
    '  * removed using cloudfront -- it doesn't cache urls with parameters
    '  * LB ec2 instances are using squid caching - we cache uri parameters too!
    rt_url = "http://api.rottentomatoes.com"
    rt_proxy = "http://rarflix-1338312912.us-west-2.elb.amazonaws.com:8888" ' ELB -> [2 ec2 reverse squid proxies] -> RT api
    'rt_proxy = "http://d1gah69i16tuow.cloudfront.net" ' cloudfront -> ELB ...
    if rt_proxy <> invalid then rt_url = rt_proxy
    url = rt_url + "/api/public/v1.0/movies.json?apikey="+apikey+"&page_limit=1&q=" + movieTitle
    Debug("Calling Rotten Tomatoes API for " + movieTitle)

    httpRequest = NewHttp(url)
    data = httpRequest.GetToStringWithTimeout(5)

    ' we are already caching the RT API calls via squid - we may want to store locally ( that's another day )
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
