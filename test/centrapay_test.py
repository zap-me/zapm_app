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
CLIENT_ID = os.environ.get('CLIENT_ID')
MERCHANT_API_KEY = os.environ.get('MERCHANT_API_KEY')

def construct_parser():
    # construct argument parser
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command")

    ## Account / Device creation

    parser_req_create = subparsers.add_parser("request_create", help="Create an request")
    parser_req_create.add_argument("amount", metavar="AMOUNT", type=str, help="the request amount")
    parser_req_create.add_argument("asset", metavar="ASSET", type=str, help="the asset")

    parser_req_info = subparsers.add_parser("request_info", help="Check a request")
    parser_req_info.add_argument("request_id", metavar="REQUEST_ID", type=str, help="the request id")

    parser_req_pay = subparsers.add_parser("request_pay", help="Pay a request")
    parser_req_pay.add_argument("request_id", metavar="REQUEST_ID", type=str, help="the id of the request to pay")
    parser_req_pay.add_argument("ledger", metavar="LEDGER", type=str, help="the selected payment option to use")
    parser_req_pay.add_argument("authorization", metavar="AUTHORIZATION", type=str, help="an identifier that can be used to pay or verify payment")

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
    print(curlify(r.request))
    check(r)
    return r

def print_centrapay_qrcode(request_id):
    qr = qrcode.QRCode()
    qr.add_data('{}/{}'.format(CENTRAPAY_PAY_BASE_URI, request_id))
    qr.print_ascii(tty=True)

def request_create(args):
    r = request_('/payments/api/requests.create', dict(merchantId=MERCHANT_ID, clientId=CLIENT_ID, amount=args.amount, asset=args.asset))
    request_id = r.json()['requestId']
    print_centrapay_qrcode(request_id)
    print(r.json())
    
def request_info(args):
    r = request_('/payments/api/requests.info', dict(requestId=args.request_id), post=False)
    request_id = r.json()['requestId']
    print_centrapay_qrcode(request_id)
    print(r.json())

def request_pay(args):
    r = request_('/payments/api/requests.pay', dict(requestId=args.request_id, ledger=args.ledger, authorization=args.authorization))
    print(r.json())

if __name__ == "__main__":
    # parse arguments
    parser = construct_parser()
    args = parser.parse_args()

    # set appropriate function
    function = None
    if args.command == "request_create":
        function = request_create
    elif args.command == "request_info":
        function = request_info
    elif args.command == "request_pay":
        function = request_pay
    else:
        parser.print_help()
        sys.exit(EXIT_NO_COMMAND)

    if function:
        function(args)