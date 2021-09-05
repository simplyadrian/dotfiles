import boto3
import json
import os
from pprint import PrettyPrinter


pp = PrettyPrinter(indent=4)


def assume_role(aws_account_number):

    # Beginning the assume role process for account
    sts_client = boto3.client('sts')

    # Get the current partition
    partition = sts_client.get_caller_identity()['Arn'].split(":")[1]
    not_assumed = False
    try:
        response = sts_client.assume_role(
            RoleArn='arn:{}:iam::{}:role/{}'.format(
                partition,
                aws_account_number,
                'terraform_master'
            ),
            RoleSessionName='profileGenerator'
        )
    except Exception as e:
        print(f'errored in {aws_account_number} with terraform_master')
        not_assumed = True

    if not_assumed:
        not_assumed = False
        try:
            response = sts_client.assume_role(
                RoleArn='arn:{}:iam::{}:role/{}'.format(
                    partition,
                    aws_account_number,
                    'terraform-deploy'
                ),
                RoleSessionName='profileGenerator'
            )
        except Exception as e:
            not_assumed = True

    if not not_assumed:
        # Storing STS credentials
        session = boto3.Session(
            aws_access_key_id=response['Credentials']['AccessKeyId'],
            aws_secret_access_key=response['Credentials']['SecretAccessKey'],
            aws_session_token=response['Credentials']['SessionToken']
        )
        return session
    else:
        print(f'error assuming role to {aws_account_number}')


def get_region(account_id):
    session = assume_role(account_id)
    if session:
        for region in regions:
            ec2 = session.client('ec2', region_name=region)
            subnets = ec2.describe_subnets()
            for subnet in subnets['Subnets']:
                if region in subnet['AvailabilityZone']:
                    return region

regions = ['us-west-2', 'eu-west-2', 'ap-southeast-2']

home = os.environ["HOME"]
for root, dirs, files in os.walk(f"{home}/.aws/sso/cache"):
    for name in files:
        if 'json' in name:
            with open(os.path.join(root, name), 'r') as fp:
                data = json.load(fp)
                if 'accessToken' in data:
                    access_token = data['accessToken']
                    break

sso = boto3.client('sso', region_name='us-west-2')
accounts = {}
config_file = open('./config-file', 'a')
count = 0
response = sso.list_accounts(accessToken=access_token)
while response:
    profiles = []
    for account in response['accountList']:
        if account['accountId'] == '053076783649' or account['accountId'] == '869488015389' or account['accountId'] == '092572478152' or account['accountId'] == '165798495909':
            region = 'ap-southeast-2'
        elif account['accountId'] == '891604886088':
            region = 'us-west-2'
        else:
            region = get_region(account['accountId'])
        profiles.append(f"[profile {account['accountName'].replace('idscloud-', '').replace(' ', '_')}]")
        profiles.append('sso_start_url = https://idsgrp.awsapps.com/start')
        profiles.append(f"sso_region = us-west-2")
        profiles.append(f"sso_account_id = {account['accountId']}")
        profiles.append(f"sso_role_name = admin")
        if region:
            profiles.append(f"region = {region}")
        else:
            profiles.append(f"region = us-west-2")
        profiles.append(f"output = json")
        count += 1
    for line in profiles:
        print(line, file=config_file)
    response = sso.list_accounts(accessToken=access_token, nextToken=response['nextToken']) if 'nextToken' in response else None

config_file.close()
print(f'{count} profiles added')
