from ecdsa import SigningKey, NIST256p
from random import choice
from string import ascii_letters, digits
from io import open
from os import urandom
from base64 import urlsafe_b64encode
import json


def get_random_str(size=16):
    return ''.join(choice(ascii_letters + digits) for _ in range(size))


def main():
    private_key = SigningKey.generate(curve=NIST256p)
    public_key = private_key.get_verifying_key()

    data_bag = {
        'id': 'TODO',
        'auth': {
            'checker': {
                'username': 'checker',
                'password': get_random_str(32)
            },
            'master': {
                'username': 'master',
                'password': get_random_str(32)
            }
        },
        'flag': {
            'generator_secret': urlsafe_b64encode(urandom(32)).decode('ascii'),
            'sign_key': {
                'public': public_key.to_pem().decode('ascii').strip().replace('\n', "\n"),
                'private': private_key.to_pem().decode('ascii').strip().replace('\n', "\n")
            }
        }
    }

    print(json.dumps(data_bag, indent=2))


if __name__ == '__main__':
    main()
