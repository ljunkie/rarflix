 ' This code is adapted from the Roku SDK web_server example app.
 ' Original notices from that example are copied below.

 ' Roku Streaming Player Web Server
 ' This code was heavily influenced by darkhttpd/1.7
 ' The darkhttpd copyright notice is included below.

 '
 ' darkhttpd
 ' copyright (c) 2003-2008 Emil Mikulic.
 '
 ' Permission to use, copy, modify, and distribute this software for any
 ' purpose with or without fee is hereby granted, provided that the
 ' above copyright notice and this permission notice appear in all
 ' copies.
 ' 
 ' THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
 ' WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
 ' WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
 ' AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
 ' DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR
 ' PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 ' TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 ' PERFORMANCE OF THIS SOFTWARE.
 ' 

 ' Adapted from C to Brightscript with mods by Roku, Inc.

function ClassServer() as Object
    this = m.ClassServer
    if this=invalid
        this = CreateObject("roAssociativeArray")
        ' constants
        this.class       = "Server"
        ' members
        this.connections = invalid
        this.sockin      = invalid
        this.uptime      = invalid
        ' initializable (copied) members
        this.port            = 8888
        this.max_connections = 3
        this.num_requests    = 0
        this.timeout         = 60
        this.total_in        = 0
        this.total_out       = 0
        ' functions
        this.init     = server_init
        this.preWait  = server_prewait
        this.postWait = server_postwait
        this.close    = server_close
        this.stats    = server_stats
        ' singleton
        m.ClassServer = this
    end if
    return this
end function

function InitServer(params=invalid as Dynamic) as Object
    this = CreateObject("roAssociativeArray")
    this.append(ClassServer())
    this.init(params)
    return this
end function

function server_init(params as Dynamic)
    if params<>invalid then m.append(params)

    m.uptime = CreateObject("roTimespan")
    m.connections = CreateObject("roAssociativeArray")

    ' create incoming socket
    sockin = CreateObject("roStreamSocket")
    if sockin=invalid then errx(m, "socket()")

    ' reuse address
    if not sockin.setReuseAddr(true) then errx(m, "setsockopt(SO_REUSEADDR)",sockin.status())

    ' bind socket
    addrin = CreateObject("roSocketAddress")
    addrin.setPort(m.port)
    if not sockin.setAddress(addrin) then errx(m, "bind(port"+ Stri(m.port) +")",sockin.status())

    ' listen on socket
    if not sockin.listen(m.max_connections) then errx(m, "listen()",sockin.status())

    ' monitor socket
    sockin.setMessagePort(m.msgPort)
    sockin.notifyReadable(true)

    m.sockin = sockin

    info(m,"listening on "+addrin.getAddress())
end function

function server_prewait()
    connections = m.connections
    for each id in connections
        conn = connections[id]
        conn.checkTimeout(m.timeout)
        cs = conn.state
        if cs=conn.DONE
            conn.socket.notifyReadable(false)
            conn.socket.notifyWritable(false)
        else if cs=conn.RECV_REQUEST
            conn.socket.notifyReadable(true)
            conn.socket.notifyWritable(false)
        else if cs=conn.SEND_HEADER or cs=conn.SEND_REPLY
            conn.socket.notifyWritable(true)
            conn.socket.notifyReadable(false)
        else if cs=conn.WAITING
            if NOT conn.reply.isWaiting() then conn.setState(conn.SEND_HEADER)
        else
            errx(m, "invalid state")
        end if
    end for
end function

function server_postwait()
    connections = m.connections
    if m.sockin.isReadable()
        conn = AcceptConnection(m)
        if conn<>invalid then connections[conn.id] = conn
    end if
    for each id in connections
        conn = connections[id]
        cs = conn.state
        if cs=conn.RECV_REQUEST
            if conn.socket.isReadable() then conn.pollRequest(m)
        else if cs=conn.SEND_HEADER
            if conn.socket.isWritable() then conn.pollHeader(m)
        else if cs=conn.SEND_REPLY
            if conn.socket.isWritable() then conn.pollReply(m)
        else if cs=conn.DONE
            ' handle with other connections that might transition to done
        else if cs=conn.WAITING
            ' Do nothing
        else
            errx(m, "invalid state")
        end if
        cs = conn.state
        if cs=conn.DONE
            conn.request.conn = invalid
            if conn.close
                conn.socket.close()
                connections.delete(id)
            else
                conn.recycle()
                conn.pollRequest(m)
            end if
        end if
    end for
end function

function server_close()
    ' close all the sockets
    m.sockin.close()
    connections = m.connections
    for each id in connections
        conn = connections[id]
        conn.socket.close()
    end for
    ' final stats
    info(m,UnixNL()+m.stats())
end function

function server_stats() as String
    stats =         "  Uptime"   + Stri(m.uptime.totalSeconds()) + " secs"                + UnixNL()
    stats = stats + "  Requests" + Stri(m.num_requests)                                   + UnixNL()
    stats = stats + "  Bytes"    + Stri(m.total_in) + " in," + Stri(m.total_out) + " out"
    return stats
end function

