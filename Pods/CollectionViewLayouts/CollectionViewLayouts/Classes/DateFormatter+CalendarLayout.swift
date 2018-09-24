//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import Foundation

extension DateFormatter {
  public static var formatterWithDayOfWeekMonthDay: DateFormatter = {
    let dateFormatter = DateFormatter()
    let formatString = DateFormatter.dateFormat(fromTemplate: "EEEEMMMMdd",
                                                options: 0,
                                                locale: Locale.current)
    dateFormatter.dateFormat = formatString
    return dateFormatter
  }()

  public static var formatterWithShortDateAndTime: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .short
    dateFormatter.timeStyle = .short
    return dateFormatter
  }()

  public static var formatterWithMonthYear: DateFormatter = {
    let dateFormatter = DateFormatter()
    let formatString = DateFormatter.dateFormat(fromTemplate: "MMMMYYYY",
                                                options: 0,
                                                locale: Locale.current)
    dateFormatter.dateFormat = formatString
    return dateFormatter
  }()

  public static var formatterWithDayOfWeek: DateFormatter = {
    let dateFormatter = DateFormatter()
    let formatString = DateFormatter.dateFormat(fromTemplate: "EEEE",
                                                options: 0,
                                                locale: Locale.current)
    dateFormatter.dateFormat = formatString
    return dateFormatter
  }()

  public static var formatterWithMonth: DateFormatter = {
    let dateFormatter = DateFormatter()
    let formatString = DateFormatter.dateFormat(fromTemplate: "MMMM",
                                                options: 0,
                                                locale: Locale.current)
    dateFormatter.dateFormat = formatString
    return dateFormatter
  }()

  public static var formatterWithDay: DateFormatter = {
    let dateFormatter = DateFormatter()
    let formatString = DateFormatter.dateFormat(fromTemplate: "dd",
                                                options: 0,
                                                locale: Locale.current)
    dateFormatter.dateFormat = formatString
    return dateFormatter
  }()

  public static var formatterForEXIF: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
    return dateFormatter
  }()
}
