module StatsMods

export GetData, SaveData, LoadData, GetReturn, CalculateDistance, MatrixMap, GetLDMean, GetLDSTD

using Plots, DataFrames, CSV, MarketData, HTTP, Statistics

DataDir = "../../Data/"
FigsDir = "../../Figs/"

function GetData(Symbols::Vector{String}, StartTime::DateTime, EndTime::DateTime)
    Data = []
    for Sym in Symbols
        data = yahoo(Sym, YahooOpt(period1=StartTime, period2=EndTime))
        push!(Data, DataFrame(data))
    end
    return Data
end

function SaveData(Symbols::Vector{String}, StartTime::DateTime, EndTime::DateTime, Dir::String)
    for Sym ∈ Symbols
        data = yahoo(Sym, YahooOpt(period1=StartTime, period2=EndTime))
        CSV.write(Dir * "$Sym.csv", DataFrame(data))
    end
end

function LoadData(Symbols::Vector{String}, Dir::String)
    Data = DataFrame[]
    for Sym in Symbols
        data = CSV.read(Dir * "$Sym.csv", DataFrame)
        push!(Data, data)
    end
    return Data
end

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

    return std(Vec)
end

function GetData(Sym::String;
    Market::String="USD", StartDate::DateTime=DateTime(2018, 01, 01), EndDate::DateTime=DateTime(2022, 06, 01),
    api_key::String="API_KEY", Period::String="1DAY", SaveDir::String=DataDir * "Stage-4-Data/")
    api_address = "https://rest.coinapi.io/v1/exchangerate/"
    api_params = "/$Market/history?period_id=$Period&limit=2000&output_format=csv"
    api_time = "&time_start=$(StartDate)&time_end=$(EndDate)"
    write(SaveDir * "$Period-$Sym.csv", HTTP.get(
        api_address * Sym * api_params * api_time,
        ["X-CoinAPI-Key" => api_key]).body)
end

function LoadData(Sym::String; Period::String="1DAY", LoadDir::String=DataDir * "Stage-4-Data/")
    Normalize(Ans::Vector) = (Ans .- mean(Ans)) / std(Ans)
    df = CSV.read(LoadDir * "$Period-$Sym.csv", DataFrame)
    Returns = log.(df.rate_close) .- log.(df.rate_open)
    Prices = (df.rate_high .+ df.rate_low) / 2
    NormPrices = Normalize(Prices)
    Times = [DateTime(t[1:end-9]) for t in df.time_period_start]
    CumRet = cumprod(Returns .+ 1)
    return [Returns, CumRet, NormPrices, Times]
end

function LoadDataFrame(Sym::String; LoadDir::String=DataDir * "Stage-4-Data/")
    df = CSV.read(LoadDir * "$Sym.csv", DataFrame)
    NewDF = DataFrame()
    TurnToDateTime(str::String31) = DateTime(str[1:end-6])

    NewDF.Time = TurnToDateTime.(df.time_period_start)
    NewDF.Open = df.rate_open
    NewDF.High = df.rate_high
    NewDF.Low = df.rate_low
    NewDF.Close = df.rate_close
    return NewDF
end

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




