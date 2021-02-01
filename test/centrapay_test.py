import os
import sys
import argparse

import requests
import qrcode

EXIT_NO_COMMAND = 1
EXIT_HTTP_ERROR = 2

CENTRAPAY_PAY_BASE_URI = 'http://app.centrapay.com/pay'
CENTRAPAY_BASE_URL = 'https://service.centrapay.com'

MERCHANT_ID = os.environ.get('MERCHANT_ID')
MERCHANT_API_KEY = os.environ.get('MERCHANT_API_KEY')

def construct_parser():
    # construct argument parser
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command")

    ## Account / Device creation

    parser_req_create = subparsers.add_parser("request_create", help="Create an request")
    parser_req_create.add_argument("amount", metavar="AMOUNT", type=str, help="the request amount")
    parser_req_create.add_argument("asset", metavar="ASSET", type=str, help="the asset")

    parser_req_status = subparsers.add_parser("request_status", help="Check a request request")
    parser_req_status.add_argument("request_id", metavar="REQUEST_ID", type=str, help="the request id")

    return parser

def check(response):
    print(response.status_code)
    try:
        response.raise_for_status()
    except requests.exceptions.HTTPError as e:
        print(response.text)
        sys.exit(EXIT_HTTP_ERROR)

def curlify(req):
    command = "curl -X {method} -H {headers} -d '{data}' '{uri}'"
    method = req.method
    uri = req.url
    data = req.body
    headers = ['"{0}: {1}"'.format(k, v) for k, v in req.headers.items()]
    headers = " -H ".join(headers)
    return command.format(method=method, headers=headers, data=data, uri=uri)

def request_(endpoint, data, post=True):
    headers = {'x-api-key': MERCHANT_API_KEY}
    url = CENTRAPAY_BASE_URL + endpoint
    print(':: calling "{}"...'.format(url))
    print(':: headers:')
    print(headers)
    print(':: data:')
    print(data)
    if post:
        r = requests.post(url, headers=headers, data=data)
    else:
        r = requests.get(url, headers=headers, params=data)
    #print(curlify(r.request))
    check(r)
    return r

def print_centrapay_qrcode(request_id):
    qr = qrcode.QRCode()
    qr.add_data('{}/{}'.format(CENTRAPAY_PAY_BASE_URI, request_id))
    qr.print_ascii(tty=True)

def request_create(args):
    r = request_('/payments/api/requests.create', dict(merchantId=MERCHANT_ID, amount=args.amount, asset=args.asset))
    request_id = r.json()['requestId']
    print_centrapay_qrcode(request_id)
    print(r.json())
    
def request_status(args):
    r = request_('/payments/api/requests.info', dict(requestId=args.request_id), post=False)
    request_id = r.json()['requestId']
    print_centrapay_qrcode(request_id)
    print(r.json())

if __name__ == "__main__":
    # parse arguments
    parser = construct_parser()
    args = parser.parse_args()

    # set appropriate function
    function = None
    if args.command == "request_create":
        function = request_create
    elif args.command == "request_status":
        function = request_status
    else:
        parser.print_help()
        sys.exit(EXIT_NO_COMMAND)

    if function:
        function(args)