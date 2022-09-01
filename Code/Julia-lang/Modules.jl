module DataHandler

export GetExchangeRateData, GetAVCryptoINTRADAYData, GetAVCryptoData, GetCoinAPIData, LoadCoinAPIData, LoadCoinAPIDataFrame, LoadYahooData, GetCoinGeckoHistoryData, GetCoinGeckoData, LoadCoinGeckoDataFrame

using DataFrames, CSV, HTTP, Dates, StatsBase, JSON, JLD

DataDir = "../../Data/"
FigsDir = "../../Figs/"

function GetExchangeRateData(Base::String, StartDate::Date, EndDate::Date)
    api_address = "https://api.exchangerate.host/timeseries?"
    api_params = "start_date=$StartDate&end_date=$EndDate&base=$Base"
    REQUEST = HTTP.get(api_address * api_params)
    return JSON.parse(String(REQUEST.body))
end

function GetAVCryptoINTRADAYData(Sym::String, Market::String;
    api_key::String=(ENV["AlphaVantage_Key1"]), Interval::String="5min", SaveDir::String="")
    api_address = "https://www.alphavantage.co/query?"
    api_params = "function=CRYPTO_INTRADAY&symbol=$Sym&market=$Market&interval=$Interval&apikey=$api_key&outputsize=full&datatype=csv"
    REQUEST = try
        HTTP.get(api_address * api_params)
    catch e
        e
    end
    if REQUEST.status == 200
        write(SaveDir * "$Sym-$Market.csv", REQUEST.body)
        return REQUEST.status
    else
        return REQUEST.status
    end
end

function GetAVCryptoData(Sym::String, Market::String;
    api_key::String=(ENV["AlphaVantage_Key1"]), Interval::String="DAILY", SaveDir::String="")
    api_address = "https://www.alphavantage.co/query?"
    api_params = "function=DIGITAL_CURRENCY_$Interval&symbol=$Sym&market=$Market&apikey=$api_key&outputsize=full&datatype=csv"
    REQUEST = try
        HTTP.get(api_address * api_params)
    catch e
        e
    end
    if REQUEST.status == 200
        write(SaveDir * "$Sym-$Market.csv", REQUEST.body)
        return REQUEST.status
    else
        return REQUEST.status
    end
end

function GetAVForExData(BaseMarket::String, ToMarket::String;
    api_key::String=(ENV["AlphaVantage_Key1"]), Interval::String="DAILY", SaveDir::String="")
    api_address = "https://www.alphavantage.co/query?"
    api_params = "function=FX_$Interval&from_symbol=$BaseMarket&to_symbol=$ToMarket&outputsize=full&datatype=csv&apikey=$api_key"
    REQUEST = try
        HTTP.get(api_address * api_params)
    catch e
        e
    end
    if REQUEST.status == 200
        write(SaveDir * "$BaseMarket-$ToMarket.csv", REQUEST.body)
        return REQUEST.status
    else
        return REQUEST.status
    end
end

function GetAVForExINTRADAYData(BaseMarket::String, ToMarket::String;
    api_key::String=(ENV["AlphaVantage_Key1"]), Interval::String="5min", SaveDir::String="")
    api_address = "https://www.alphavantage.co/query?"
    api_params = "function=FX_INTRADAY&from_symbol=$BaseMarket&to_symbol=$ToMarket&interval=$Interval&apikey=$api_key&outputsize=full&datatype=csv"
    REQUEST = try
        HTTP.get(api_address * api_params)
    catch e
        e
    end
    if REQUEST.status == 200
        write(SaveDir * "$BaseMarket-$ToMarket.csv", REQUEST.body)
        return REQUEST.status
    else
        return REQUEST.status
    end
end

function GetCoinAPIData(Sym::String, Market::String;
    StartDate::DateTime=DateTime(2021, 06, 01), EndDate::DateTime=DateTime(2022, 08, 01),
    api_key::String=ENV["CoinAPI_Key1"], Period::String="1DAY", SaveDir::String="", Limit=500, OutputFormat::String="csv")
    api_address = "https://rest.coinapi.io/v1/exchangerate/"
    api_params = "/$Market/history?period_id=$Period&limit=$Limit&output_format=$OutputFormat"
    api_time = "&time_start=$(StartDate)&time_end=$(EndDate)"
    REQUEST = try
        HTTP.get(
            api_address * Sym * api_params * api_time,
            ["X-CoinAPI-Key" => api_key])
    catch e
        e
    end
    if REQUEST.status == 200
        write(SaveDir * "$Sym-$Market.csv", REQUEST.body)
        return true
    elseif REQUEST.status == 429
        error("Rate limit exceeded")
    else
        return false
    end
end

function LoadCoinAPIData(Dir::String)
    Normalize(Ans::Vector) = (Ans .- mean(Ans)) / std(Ans)
    df = CSV.read(Dir, DataFrame)
    Returns = log.(df.rate_close) .- log.(df.rate_open)
    Prices = (df.rate_high .+ df.rate_low) / 2
    NormPrices = Normalize(Prices)
    TurnToDateTime(str::AbstractString) = DateTime(str[1:end-9])
    if eltype(df.time_period_start) == Date || eltype(df.time_period_start) == DateTime
        Times = df.time_period_start
    else
        Times = try
            TurnToDateTime.(df.time_period_start)
        catch
            DateTime.(df.time_period_start, dateformat"dd/mm/yyyy")
        end
    end
    CumRet = cumprod(Returns .+ 1)
    return [Returns, CumRet, NormPrices, Times]
end

function LoadCoinAPIDataFrame(Dir::String)
    df = CSV.read(Dir, DataFrame)
    NewDF = DataFrame()
    TurnToDateTime(str::String31) = DateTime(str[1:end-9])

    if eltype(df.time_period_start) == Date || eltype(df.time_period_end) == DateTime
        NewDF.Time = df.time_period_start
    else
        NewDF.Time = try
            TurnToDateTime.(df.time_period_start)
        catch
            DateTime.(df.time_period_start, dateformat"dd/mm/yyyy")
        end
    end

    NewDF.Open = df.rate_open
    NewDF.High = df.rate_high
    NewDF.Low = df.rate_low
    NewDF.Close = df.rate_close
    return NewDF
end

function LoadYahooData(Dir::String)
    Normalize(Ans::Vector) = (Ans .- mean(Ans)) / std(Ans)
    df = CSV.read(Dir, DataFrame)
    Returns = log.(df.Close) .- log.(df.Open)
    Prices = (df.High .+ df.Low) / 2
    NormPrices = Normalize(Prices)
    Times = df.Date
    CumRet = cumprod(Returns .+ 1)
    return [Returns, CumRet, NormPrices, Times]
end

function GetCoinGeckoData(CoinID::String, Market::String; Interval::String="daily", DaysLimit="max")
    api_address = "https://api.coingecko.com/api/v3/coins/"
    api_params = "/market_chart?vs_currency=$Market&days=$DaysLimit&interval=$Interval"
    REQUEST = try
        HTTP.get(
            api_address * CoinID * api_params)
    catch e
        e
    end
    if REQUEST.status == 200
        return JSON.parse(String(REQUEST.body))
    else
        return REQUEST.status
    end
end

function GetCoinGeckoHistoryData(CoinID::String, HistoryDate::Date)
    y, m, d = year(HistoryDate), month(HistoryDate), day(HistoryDate)
    api_address = "https://api.coingecko.com/api/v3/coins/"
    api_params = "/history?date=$d-$m-$y"
    REQUEST = try
        HTTP.get(
            api_address * CoinID * api_params)
    catch e
        e
    end
    if REQUEST.status == 200
        return JSON.parse(String(REQUEST.body))
    else
        return REQUEST.status
    end
end

function LoadCoinGeckoDataFrame(Dir::String)
    Data = load(Dir)
    Markets = keys(Data)
    MarketsDataFrameDict = Dict()
    for Market ∈ Markets
        df = DataFrame()
        df.Price = replace(getindex.(Data[Market]["prices"], 2), nothing => missing)
        df.Date = unix2datetime.(getindex.(Data[Market]["prices"], 1) / 1000)
        df.TotalVolume = replace(getindex.(Data[Market]["total_volumes"], 2), nothing => missing)
        df.MarketCap = replace(getindex.(Data[Market]["market_caps"], 2), nothing => missing)
        df.Returns = [0.0; log.(df.Price[2:end]) .- log.(df.Price[1:end-1])]
        MarketsDataFrameDict[Market] = df
    end
    return MarketsDataFrameDict
end

end

module ShowMatrix

export matrixmap

using Plots

@userplot MatrixMap
@recipe function f(x::MatrixMap; annotationargs=())
    #Get the input arguments, stored in x.args - in this case there's only one
    typeof(x.args[1]) <: AbstractVector || error("Pass a Vector as the x to heatmap")
    typeof(x.args[2]) <: AbstractVector || error("Pass a Vector as the y to heatmap")
    typeof(x.args[3]) <: AbstractMatrix || error("Pass a Matrix as the z to heatmap")

    @series begin                      # the main series, showing the heatmap
        seriestype := :heatmap
        x.args[1], x.args[2], x.args[3]
    end

    rows, cols = size(x.args[3])

    @series begin
        seriescolor := RGBA(0, 0, 0, 0.0)
        series_annotations := text.(vec(round.(x.args[3], digits=3)), annotationargs...)
        primary := false
        xrotation := 30
        xticks := (0.5:rows, x.args[1])
        yticks := (0.5:cols, x.args[2])
        repeat(x.args[1], inner=rows), repeat(x.args[2], outer=cols)
    end
end
end

module ExtraStats
export GetReturn, GetCumReturn, CalculateDistance, GetLDSTD, GetLDMean

using DataFrames, StatsBase

GetReturn(df::DataFrame) = log.(df.Close) .- log.(df.Open)
GetCumReturn(df::DataFrame) = cumprod(log.(df.Close) .- log.(df.Open) .+ 1)
CalculateDistance(c::AbstractFloat) = √2 * (1 - c)

function GetLDSTD(Mat)
    cols, rows = size(Mat)
    Vec = Float64[]

    for i ∈ 1:cols
        for j ∈ 1:rows
            if i + j <= (rows + cols) / 2
                push!(Vec, rotr90(Mat)[i, j])
            end
        end
    end

    return std(Vec)
end

function GetLDMean(Mat)
    cols, rows = size(Mat)
    Vec = Float64[]

    for i ∈ 1:cols
        for j ∈ 1:rows
            if i + j <= (rows + cols) / 2
                push!(Vec, rotr90(Mat)[i, j])
            end
        end
    end

    return mean(Vec)
end

end