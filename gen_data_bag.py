from ecdsa import SigningKey, NIST256p
from random import choice
from string import ascii_letters, digits
from io import open
from os import urandom
from base64 import urlsafe_b64encode
import json
import argparse
import uuid


def get_random_str(size=16):
    return ''.join(choice(ascii_letters + digits) for _ in range(size))


def main(name, environment):
    if name == 'postgres':
        return {
            'id': environment,
            'password': {
                'postgres': get_random_str(24),
                'volgactf_final': get_random_str(24)
            }
        }
    elif name == 'redis':
        return {
            'id': environment,
            'password': get_random_str(24)
        }
    elif name == 'volgactf-final':
        private_key = SigningKey.generate(curve=NIST256p)
        public_key = private_key.get_verifying_key()

        return {
            'id': environment,
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
    elif name == 'netdata':
        return {
            'id': 'development',
            'stream': {
                'api_key': {
                    'master_server': str(uuid.uuid4()),
                    'redis_server': str(uuid.uuid4()),
                    'postgres_server': str(uuid.uuid4()),
                    'checker1_server': str(uuid.uuid4())
                }
            }
        }
    else:
        return None


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generate sample data bag')
    parser.add_argument('name', type=str)
    parser.add_argument('--env', dest='environment', type=str, default='development')
    args = parser.parse_args()
    data = main(args.name, args.environment)
    if data is not None:
        print(json.dumps(data, indent=2))
    else:
        print('data bag <{0}>: unavailable'.format(args.name))
