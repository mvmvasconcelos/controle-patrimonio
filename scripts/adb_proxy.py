import socket
import select
import sys

def main(local_port, remote_port):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(('0.0.0.0', local_port))
        server.listen(5)
    except Exception as e:
        print(f"Failed to bind: {e}")
        sys.exit(1)

    print(f"Proxy listening on 0.0.0.0:{local_port} -> localhost:{remote_port}")

    while True:
        client_socket, addr = server.accept()
        print(f"Accepted connection from {addr}")

        try:
            remote_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            remote_socket.connect(('127.0.0.1', remote_port))
        except Exception as e:
            print(f"Failed to connect to remote: {e}")
            client_socket.close()
            continue

        sockets = [client_socket, remote_socket]

        while True:
            readable, _, _ = select.select(sockets, [], [])
            if not readable:
                break
            
            for s in readable:
                other = sockets[1] if s is sockets[0] else sockets[0]
                try:
                    data = s.recv(4096)
                    if not data:
                        # Connection closed
                        for sock in sockets:
                            sock.close()
                        break
                    other.sendall(data)
                except Exception as e:
                    print(f"Error forwarding: {e}")
                    for sock in sockets:
                        sock.close()
                    break
            else:
                continue
            break
        
        # print("Connection closed")

if __name__ == '__main__':
    # Port 5556 (accessible by Docker) -> 5555 (SSH Tunnel to Emulator)
    main(5556, 5555)
