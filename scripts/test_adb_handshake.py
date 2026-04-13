import socket
import sys

def test_handshake(host, port):
    print(f"Connecting to {host}:{port}...")
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(5) # 5 seconds timeout
        s.connect((host, port))
        
        # ADB Host Protocol: 4-byte hex length + payload
        # Requesting version: "host:version" -> length 12 -> "000C"
        msg = b"000Chost:version"
        print(f"Sending: {msg}")
        s.sendall(msg)
        
        # Expecting "OKAY" + 4-byte hex length + payload
        response = s.recv(1024)
        print(f"Received ({len(response)} bytes): {response}")
        
        if response.startswith(b"OKAY"):
            print("SUCCESS: Handshake accepted!")
        else:
            print("FAILURE: Invalid response.")
            
        s.close()
    except Exception as e:
        print(f"ERROR: {e}")

if __name__ == "__main__":
    print("\n--- Testing via Tunnel (127.0.0.1:5557) ---")
    test_handshake("127.0.0.1", 5557)
