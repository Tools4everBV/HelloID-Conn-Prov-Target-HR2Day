# HelloID-Conn-Prov-Target-HR2Day

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as clientid, clientsecret, BaseUrl etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.       |

<br />

<p align="center">
  <img src="https://github.com/Tools4everBV/HelloID-Conn-Prov-Source-HR2Day/blob/main/Logo.png">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-HR2Day](#helloid-conn-prov-target-hr2day)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Connection settings](#connection-settings)
    - [Prerequisites](#prerequisites)
      - [TLS1.2](#tls12)
      - [Pagination](#pagination)
    - [Contents](#contents)
  - [Setup the connector](#setup-the-connector)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

HR2Day is an HR System and provides a set of REST API's that allow you to programmatically interact with it's data. The HelloID connector uses the API endpoints in the table below.

| Endpoint | Description |
| ------------ | ----------- |
| /Emloyee | Contains the employee information. |

## Getting started

The _HelloID-Conn-Prov-Source-HR2Day_ connector is created for both Windows PowerShell 5.1 and PowerShell Core. This means that the connector can be executed in both cloud and on-premises using the HelloID agent.
By using this connector you will have the ability to update employee Email address in the HR2Day system.

### HelloID Icon URL
URL of the icon used for the HelloID Provisioning target system.

```
https://github.com/Tools4everBV/HelloID-Conn-Prov-Source-HR2Day/blob/main/Icon.png
```

### Provisioning PowerShell V2 connector

#### Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within _{connectorName}_ to a person in _HelloID_.

To properly setup the correlation:

1. Open the `Correlation` tab.

2. Specify the following configuration:

    | Setting                   | Value        |
    | ------------------------- | ------------ |
    | Enable correlation        | `True`       |
    | Person correlation field  | ``           |
    | Account correlation field | `IDS` |

> [!TIP]
> _For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages_.

#### Field mapping

The field mapping can be imported by using the [_fieldMapping.json_](./fieldMapping.json) file.

> [!TIP]
> `employee.hr2d__emailwork__c` is an field that can be mapped.

### Connection settings

The following settings are required to connect to the API.

| Setting     | Description | Mandatory |
| ------------ | ----------- | ----------- |
| ClientID | The consumer clientid. This will be provided by HR2Day | Yes |
| ClientSecret | The consumer clientsecret. This will be provided by HR2Day | Yes |
| BaseUrl | The URL to connect to the API | Yes |
| Username | The UserName to connect to the API. This will be provided by HR2Day  | Yes |
| RequesterId | The name of the 'requester' used in updating the users. This will be provided by HR2Day  | Yes |

### Prerequisites

- [ ] Make sure to have gathered all necessary connection settings


### Contents

| Files       | Description                                |
| ----------- | ------------------------------------------ |
| configuration.json | The configuration settings for the connector |
| create.ps1 | PowerShell correlate lifecycle action. Correlates |
| update.ps1 | PowerShell update lifecycle action. Update on correlate and update on update |  
| delete.ps1 | PowerShell delete lifecycle action. Clear the fields |    
| fieldMapping.json | Default fieldMapping.json |

## Setup the connector

For more information about the connector. Please check the [HR2Day documentation](https://hr2day-6087.my.site.com/hr2daydeveloper/s/)
For help setting up a new source connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012388639-How-to-add-a-source-system)

## Getting help

> [!TIP]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/Source-systems/powershell-v2-Source-systems.html) pages_.

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
