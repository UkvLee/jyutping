import CoreIME
import Darwin
import Foundation

private struct Benchmark: Sendable {
        let name: String
        let operation: @Sendable () async -> Int
}

private struct Configuration {
        var filter: String?
        var iterations = 50
        var warmups = 5
        var listsBenchmarks = false

        init(arguments: [String]) throws {
                var index = 0
                while index < arguments.count {
                        switch arguments[index] {
                        case "--filter":
                                filter = try Self.value(after: &index, in: arguments, option: "--filter")
                        case "--iterations":
                                iterations = try Self.positiveInteger(after: &index, in: arguments, option: "--iterations")
                        case "--warmup":
                                warmups = try Self.nonnegativeInteger(after: &index, in: arguments, option: "--warmup")
                        case "--list":
                                listsBenchmarks = true
                        case "--help", "-h":
                                Self.printUsage()
                                exit(EXIT_SUCCESS)
                        default:
                                throw ArgumentError("Unknown option: \(arguments[index])")
                        }
                        index += 1
                }
        }

        static func printUsage() {
                print("""
                Usage: CoreIMEBenchmarks [options]

                  --filter <text>       Run benchmarks whose names contain text
                  --iterations <count>  Measured iterations per benchmark (default: 50)
                  --warmup <count>      Warmup iterations per benchmark (default: 5)
                  --list                List benchmark names without running them
                  --help, -h            Show this help
                """)
        }

        private static func value(after index: inout Int, in arguments: [String], option: String) throws -> String {
                index += 1
                guard index < arguments.count else {
                        throw ArgumentError("Missing value for \(option)")
                }
                return arguments[index]
        }

        private static func positiveInteger(after index: inout Int, in arguments: [String], option: String) throws -> Int {
                let value = try value(after: &index, in: arguments, option: option)
                guard let integer = Int(value), integer > 0 else {
                        throw ArgumentError("\(option) requires a positive integer")
                }
                return integer
        }

        private static func nonnegativeInteger(after index: inout Int, in arguments: [String], option: String) throws -> Int {
                let value = try value(after: &index, in: arguments, option: option)
                guard let integer = Int(value), integer >= 0 else {
                        throw ArgumentError("\(option) requires a nonnegative integer")
                }
                return integer
        }
}

private struct ArgumentError: Error, CustomStringConvertible {
        let description: String

        init(_ description: String) {
                self.description = description
        }
}

@main
private struct CoreIMEBenchmarks {

        static func main() async {
                do {
                        let configuration = try Configuration(arguments: Array(CommandLine.arguments.dropFirst()))
                        if configuration.listsBenchmarks {
                                benchmarkNames.forEach({ print($0) })
                                return
                        }

                        Engine.prepare()
                        let benchmarks = makeBenchmarks()
                        let selected = benchmarks.filter({ benchmark in
                                configuration.filter.map({ benchmark.name.localizedCaseInsensitiveContains($0) }) ?? true
                        })
                        guard selected.isEmpty == false else {
                                throw ArgumentError("No benchmarks match the supplied filter")
                        }

                        print("CoreIME benchmarks (\(configuration.iterations) iterations, \(configuration.warmups) warmups)")
                        print("Build with -c release for meaningful results.\n")

                        var checksum = 0
                        for benchmark in selected {
                                let result = await measure(benchmark, configuration: configuration)
                                checksum &+= result.checksum
                                printResult(name: benchmark.name, median: result.median, p95: result.p95)
                        }
                        print("\nChecksum: \(checksum)")
                } catch {
                        print("Error: \(error)\n")
                        Configuration.printUsage()
                        exit(EXIT_FAILURE)
                }
        }

        private static func measure(_ benchmark: Benchmark, configuration: Configuration) async -> (median: UInt64, p95: UInt64, checksum: Int) {
                var checksum = 0
                for _ in 0..<configuration.warmups {
                        checksum &+= await benchmark.operation()
                }

                var durations = [UInt64]()
                durations.reserveCapacity(configuration.iterations)
                for _ in 0..<configuration.iterations {
                        let start = DispatchTime.now().uptimeNanoseconds
                        checksum &+= await benchmark.operation()
                        durations.append(DispatchTime.now().uptimeNanoseconds - start)
                }

                durations.sort()
                let middle = durations.count / 2
                let median: UInt64
                if durations.count.isMultiple(of: 2) {
                        median = durations[middle - 1] + (durations[middle] - durations[middle - 1]) / 2
                } else {
                        median = durations[middle]
                }
                let p95Index = Int(ceil(Double(durations.count) * 0.95)) - 1
                return (median, durations[p95Index], checksum)
        }

        private static func printResult(name: String, median: UInt64, p95: UInt64) {
                let paddedName = name.padding(toLength: 43, withPad: " ", startingAt: 0)
                print("\(paddedName) median \(format(median))  p95 \(format(p95))")
        }

        private static func format(_ nanoseconds: UInt64) -> String {
                let microseconds = Double(nanoseconds) / 1_000
                if microseconds < 1_000 {
                        return String(format: "%8.2f us", microseconds)
                }
                return String(format: "%8.2f ms", microseconds / 1_000)
        }

        private static func makeBenchmarks() -> [Benchmark] {
                let jyutpingKeys = inputKeys("ngong")
                let ambiguousKeySets: [Set<VirtualInputKey>] = [
                        [.letterF, .letterG],
                        [.letterO],
                        [.letterN],
                        [.letterG, .letterH]
                ]
                let nineKeyCombos = inputCombos([6, 4, 6, 6, 4])
                let pinyinKeys = inputKeys("xianshi")
                let pinyinNineKeyCombos = inputCombos([9, 4, 2, 6, 7, 4, 4])

                let suggestionKeys = inputKeys("neihou")
                let suggestionSegmentation = Segmenter.segment(suggestionKeys)
                let partialKeys = inputKeys("ngoz")
                let partialSegmentation = Segmenter.segment(partialKeys)
                let repeatedKeys = inputKeys(String(repeating: "ngaam", count: 5))
                let repeatedSegmentation = Segmenter.segment(repeatedKeys)
                let suggestionNineKeyCombos = inputCombos([6, 4, 6])
                let suggestionNineKeySegmentation = NineKeySegmenter.segment(suggestionNineKeyCombos)
                let pinyinSegmentation = PinyinSegmenter.segment(pinyinKeys)
                let pinyinNineKeySegmentation = PinyinNineKeySegmenter.segment(pinyinNineKeyCombos)

                return [
                        Benchmark(name: "segmentation/jyutping-ambiguous", operation: {
                                Segmenter.segment(jyutpingKeys).count
                        }),
                        Benchmark(name: "segmentation/jyutping-key-sets", operation: {
                                Segmenter.bestSegmentedKeys(from: ambiguousKeySets).count
                        }),
                        Benchmark(name: "segmentation/jyutping-nine-key", operation: {
                                NineKeySegmenter.segment(nineKeyCombos).count
                        }),
                        Benchmark(name: "segmentation/pinyin-ambiguous", operation: {
                                PinyinSegmenter.segment(pinyinKeys).count
                        }),
                        Benchmark(name: "segmentation/pinyin-nine-key", operation: {
                                PinyinNineKeySegmenter.segment(pinyinNineKeyCombos).count
                        }),
                        Benchmark(name: "suggestions/jyutping-full", operation: {
                                Engine.suggest(suggestionKeys, segmentation: suggestionSegmentation).count
                        }),
                        Benchmark(name: "suggestions/jyutping-partial", operation: {
                                Engine.suggest(partialKeys, segmentation: partialSegmentation).count
                        }),
                        Benchmark(name: "suggestions/jyutping-repeated-ngaam", operation: {
                                Engine.suggest(repeatedKeys, segmentation: repeatedSegmentation).count
                        }),
                        Benchmark(name: "suggestions/jyutping-nine-key", operation: {
                                await NineKeyEngine.suggest(combos: suggestionNineKeyCombos, segmentation: suggestionNineKeySegmentation).count
                        }),
                        Benchmark(name: "suggestions/pinyin-reverse-lookup", operation: {
                                await Engine.pinyinReverseLookup(pinyinKeys, segmentation: pinyinSegmentation).count
                        }),
                        Benchmark(name: "suggestions/pinyin-nine-key-reverse", operation: {
                                await Engine.pinyinNineKeyReverseLookup(combos: pinyinNineKeyCombos, segmentation: pinyinNineKeySegmentation).count
                        })
                ]
        }

        private static let benchmarkNames = [
                "segmentation/jyutping-ambiguous",
                "segmentation/jyutping-key-sets",
                "segmentation/jyutping-nine-key",
                "segmentation/pinyin-ambiguous",
                "segmentation/pinyin-nine-key",
                "suggestions/jyutping-full",
                "suggestions/jyutping-partial",
                "suggestions/jyutping-repeated-ngaam",
                "suggestions/jyutping-nine-key",
                "suggestions/pinyin-reverse-lookup",
                "suggestions/pinyin-nine-key-reverse"
        ]

        private static func inputKeys(_ text: String) -> [VirtualInputKey] {
                return text.compactMap({ character in
                        switch character {
                        case "'": VirtualInputKey.apostrophe
                        case "`": VirtualInputKey.grave
                        default: VirtualInputKey.matchInputKey(for: character)
                        }
                })
        }

        private static func inputCombos(_ digits: [Int]) -> [Combo] {
                return digits.compactMap(Combo.init(rawValue:))
        }
}
