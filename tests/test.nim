import curlyfork, std/options, std/os
const badurl = "https://eafeafaef.localhost.com"

block:
  let curl = newCurly()

  var headers: HttpHeaders
  headers["Accept-Encoding"] = "gzip"

  let getResponse = curl.get("https://www.google.com", headers)
  doAssert getResponse.code == 200
  doAssert getResponse.headers.len > 0
  doAssert getResponse.body.len > 0

  doAssert getResponse.request.verb == "GET"
  doAssert getResponse.request.url == "https://www.google.com"
  # doAssert getResponse.url == "https://www.google.com/"

  let headResponse = curl.head("https://www.google.com")
  doAssert headResponse.code == 200
  doAssert getResponse.headers.len > 0
  doAssert headResponse.body.len == 0

  doAssertRaises CatchableError:
    discard curl.get(badurl)

  doAssert curl.queueLen == 0
  doAssert curl.numInFlight == 0
  doAssert not curl.hasRequests

  curl.close()

block:
  let curl = newCurly()

  var batch: RequestBatch
  batch.get("https://www.microsoft.com")
  batch.get(badurl, tag = "tag_test")
  batch.get("https://news.ycombinator.com/")

  echo batch.len

  let rb = curl.makeRequests(batch)

  doAssert rb[0].error == ""
  doAssert rb[1].error != ""
  doAssert rb[2].error == ""

  doAssert rb[0].response.code == 200
  doAssert rb[2].response.code == 200

  doAssert rb[0].response.headers.len > 0
  doAssert rb[2].response.headers.len > 0

  doAssert rb[0].response.body.len > 0
  doAssert rb[2].response.body.len > 0

  doAssert rb[2].response.request.verb == "GET"
  doAssert rb[2].response.request.url == "https://news.ycombinator.com/"
  doAssert rb[2].response.url == "https://news.ycombinator.com/"

  doAssert rb[1].response.request.tag == "tag_test"

  for i, (response, error) in rb:
    echo batch[i].verb, ' ', batch[i].url, " => ", response.code

  doAssert curl.queueLen == 0
  doAssert curl.numInFlight == 0
  doAssert not curl.hasRequests

  curl.close()

block:
  let curl = newCurly(0)

  proc threadProc(curl: Curly) =
    try:
      discard curl.get(badurl)
    except:
      doAssert getCurrentExceptionMsg() == "Canceled in clearQueue"

  var threads = newSeq[Thread[Curly]](10)
  for thread in threads.mitems:
    createThread(thread, threadProc, curl)

  while curl.queueLen != threads.len:
    sleep(1)

  curl.clearQueue()

  joinThreads(threads)

  doAssert curl.queueLen == 0
  doAssert curl.numInFlight == 0
  doAssert not curl.hasRequests

block:
  let curl = newCurly()

  var batch: RequestBatch
  batch.get("https://www.yahoo.com")
  batch.get(badurl, tag = "tag_test")
  batch.get("https://nim-lang.org")

  curl.startRequests(batch, timeout = 10)

  for i in 0 ..< batch.len:
    let (response, error) = curl.waitForResponse()
    if error == "":
      echo response.request.url
    else:
      echo error

  doAssert curl.queueLen == 0
  doAssert curl.numInFlight == 0
  doAssert not curl.hasRequests

block:
  let curl = newCurly(0)

  var batch: RequestBatch
  batch.get(badurl)
  batch.get(badurl)
  batch.get(badurl)
  batch.get(badurl)

  curl.startRequests(batch)

  doAssert curl.queueLen == batch.len
  doAssert curl.numInFlight == 0
  doAssert curl.hasRequests

  curl.clearQueue()

  doAssert curl.queueLen == 0

  for i in 0 ..< batch.len:
    let (response, error) = curl.waitForResponse()
    doAssert error == "Canceled in clearQueue"

block:
  let curl = newCurly()

  curl.startRequest("GET", badurl, tag = $0)

  var i: int
  while true:
    let (response, error) = curl.waitForResponse()
    doAssert response.request.verb == "GET"
    doAssert response.request.url == badurl
    doAssert response.request.tag == $i
    if i < 10:
      inc i
      curl.startRequest("GET", badurl, tag = $i)
    else:
      break

block:
  let curl = newCurly(1)

  curl.startRequest("GET", badurl)

  while true:
    let answer = curl.pollForResponse()
    if answer.isSome:
      doAssert answer.get.error != ""
      break

block:
  let curlPool = newCurlPool(3)

  curlPool.withHandle curl:
    let response = curl.get("https://www.google.com")
    doAssert response.code == 200
    doAssert response.headers.len > 0
    doAssert response.body.len > 0

    doAssert response.request.verb == "GET"
    doAssert response.request.url == "https://www.google.com"
    doAssert response.url == "https://www.google.com/"

  curlPool.withHandle curl:
    let response = curl.head("https://www.google.com")
    doAssert response.code == 200
    doAssert response.headers.len > 0
    doAssert response.body.len == 0

  doAssertRaises CatchableError:
    echo curlPool.get(badurl)

  curlPool.close()
